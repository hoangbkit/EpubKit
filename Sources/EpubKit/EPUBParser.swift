import Foundation

public struct EPUBParser: Sendable {
    public init() {}

    public func parse(
        fileURL: URL,
        options: EPUBParsingOptions = .default,
        onProgress: (@Sendable (EPUBParsingProgress) -> Void)? = nil
    ) throws -> EPUBDocument {
        try throwIfCancelled()

        let reader = try ArchiveDataReader(fileURL: fileURL, options: options)
        var diagnostics: [EPUBDiagnostic] = []

        let hasEncryptionXML = reader.contains("META-INF/encryption.xml")
        if hasEncryptionXML, options.detectEncryptedEPUB {
            diagnostics.append(
                EPUBDiagnostic(
                    severity: .warning,
                    message: "META-INF/encryption.xml exists. This may be DRM or only encrypted/obfuscated font resources. Text extraction will continue.",
                    path: "META-INF/encryption.xml"
                )
            )
        }

        guard reader.contains("META-INF/container.xml") else {
            throw EPUBParserError.missingContainer
        }

        let containerXML = try reader.readString("META-INF/container.xml")
        let packagePath = try ContainerParser().parse(containerXML)

        guard reader.contains(packagePath) else {
            throw EPUBParserError.missingPackageDocument(packagePath)
        }

        let packageXML = try reader.readString(packagePath)
        let opf = try OPFParser().parse(packageXML, path: packagePath)
        let opfBasePath = EPUBPathResolver.dirname(packagePath)

        if opf.metadata.renditionLayout == "pre-paginated" {
            diagnostics.append(
                EPUBDiagnostic(
                    severity: .warning,
                    message: "This looks like a fixed-layout EPUB. Text extraction may be incomplete or out of visual order.",
                    path: packagePath
                )
            )
        }

        let toc = options.parseTableOfContentsTitles
            ? loadTOC(reader: reader, opf: opf, opfBasePath: opfBasePath, diagnostics: &diagnostics)
            : EPUBTOC()
        let cover = loadCover(reader: reader, opf: opf, opfBasePath: opfBasePath, diagnostics: &diagnostics)

        var chapters: [EPUBChapter] = []
        let totalSpineItems = opf.spine.count

        for (spineIndex, idref) in opf.spine.enumerated() {
            try throwIfCancelled()

            guard let item = opf.manifest[idref] else {
                diagnostics.append(
                    EPUBDiagnostic(
                        severity: .warning,
                        message: "Spine item references a missing manifest item: \(idref).",
                        path: packagePath
                    )
                )
                continue
            }

            guard isReadableHTML(item) else {
                continue
            }

            let fullPath = EPUBPathResolver.resolve(basePath: opfBasePath, href: item.href)
            onProgress?(
                EPUBParsingProgress(
                    completedSpineItems: spineIndex,
                    totalSpineItems: totalSpineItems,
                    currentPath: fullPath
                )
            )

            do {
                let html = try reader.readString(fullPath)
                let extracted = try HTMLTextExtractor.extract(html: html, path: fullPath, options: options)
                let cleanText = extracted.text.trimmingCharacters(in: .whitespacesAndNewlines)

                if cleanText.isEmpty, options.dropEmptyChapters {
                    diagnostics.append(
                        EPUBDiagnostic(
                            severity: .info,
                            message: "Dropped an empty chapter.",
                            path: fullPath
                        )
                    )
                    continue
                }

                let title = toc.title(forResolvedPath: fullPath)
                    ?? extracted.title
                    ?? idref.epub_trimmedOrNil

                chapters.append(
                    EPUBChapter(
                        id: idref,
                        order: chapters.count,
                        title: title,
                        href: fullPath,
                        mediaType: item.mediaType,
                        properties: item.properties,
                        text: cleanText
                    )
                )
            } catch let error as EPUBParserError {
                diagnostics.append(
                    EPUBDiagnostic(
                        severity: .warning,
                        message: error.localizedDescription,
                        path: fullPath
                    )
                )
            } catch {
                diagnostics.append(
                    EPUBDiagnostic(
                        severity: .warning,
                        message: "Failed to parse chapter: \(error.localizedDescription)",
                        path: fullPath
                    )
                )
            }
        }

        onProgress?(
            EPUBParsingProgress(
                completedSpineItems: totalSpineItems,
                totalSpineItems: totalSpineItems,
                currentPath: nil
            )
        )

        if chapters.isEmpty {
            if hasEncryptionXML, options.detectEncryptedEPUB {
                throw EPUBParserError.encryptedEPUB
            }
            throw EPUBParserError.noReadableContent
        }

        return EPUBDocument(
            metadata: opf.metadata,
            chapters: chapters,
            cover: cover,
            tableOfContents: toc.items,
            diagnostics: diagnostics
        )
    }

    public func parseAsync(
        fileURL: URL,
        options: EPUBParsingOptions = .default,
        priority: TaskPriority? = nil,
        onProgress: (@Sendable (EPUBParsingProgress) -> Void)? = nil
    ) async throws -> EPUBDocument {
        try throwIfCancelled()

        let task = Task.detached(priority: priority) {
            try self.parse(fileURL: fileURL, options: options, onProgress: onProgress)
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private func throwIfCancelled() throws {
        do {
            try Task.checkCancellation()
        } catch {
            throw EPUBParserError.cancelled
        }
    }

    private func isReadableHTML(_ item: OPFManifestItem) -> Bool {
        let mediaType = item.mediaType.lowercased()
        let href = item.href.lowercased()

        return mediaType == "application/xhtml+xml"
            || mediaType == "text/html"
            || mediaType == "application/html"
            || href.hasSuffix(".xhtml")
            || href.hasSuffix(".html")
            || href.hasSuffix(".htm")
    }

    private func loadCover(
        reader: ArchiveDataReader,
        opf: OPFDocument,
        opfBasePath: String,
        diagnostics: inout [EPUBDiagnostic]
    ) -> EPUBCover? {
        let epub3Cover = opf.manifest.values.first {
            $0.properties.contains { $0.caseInsensitiveCompare("cover-image") == .orderedSame }
        }
        let legacyCover = opf.coverItemID.flatMap { opf.manifest[$0] }

        guard let item = epub3Cover ?? legacyCover else {
            return nil
        }

        let coverPath = EPUBPathResolver.resolve(basePath: opfBasePath, href: item.href)
        guard item.mediaType.lowercased().hasPrefix("image/") else {
            diagnostics.append(
                EPUBDiagnostic(
                    severity: .info,
                    message: "EPUB cover metadata points to a non-image resource.",
                    path: coverPath
                )
            )
            return nil
        }

        do {
            let data = try reader.readData(coverPath)
            return EPUBCover(data: data, mediaType: item.mediaType, href: coverPath)
        } catch {
            diagnostics.append(
                EPUBDiagnostic(
                    severity: .info,
                    message: "Unable to load EPUB cover: \(error.localizedDescription)",
                    path: coverPath
                )
            )
            return nil
        }
    }

    private func loadTOC(
        reader: ArchiveDataReader,
        opf: OPFDocument,
        opfBasePath: String,
        diagnostics: inout [EPUBDiagnostic]
    ) -> EPUBTOC {
        if let navItem = opf.manifest.values.first(where: { $0.properties.contains("nav") }) {
            let navPath = EPUBPathResolver.resolve(basePath: opfBasePath, href: navItem.href)
            do {
                let navHTML = try reader.readString(navPath)
                return NavDocumentParser.parse(navHTML, basePath: EPUBPathResolver.dirname(navPath))
            } catch {
                diagnostics.append(
                    EPUBDiagnostic(
                        severity: .info,
                        message: "Unable to parse EPUB nav document: \(error.localizedDescription)",
                        path: navPath
                    )
                )
            }
        }

        let ncxItem: OPFManifestItem?
        if let tocID = opf.tocID, let item = opf.manifest[tocID] {
            ncxItem = item
        } else {
            ncxItem = opf.manifest.values.first { $0.mediaType == "application/x-dtbncx+xml" || $0.href.lowercased().hasSuffix(".ncx") }
        }

        if let ncxItem {
            let ncxPath = EPUBPathResolver.resolve(basePath: opfBasePath, href: ncxItem.href)
            do {
                let ncxXML = try reader.readString(ncxPath)
                return NCXParser(basePath: EPUBPathResolver.dirname(ncxPath)).parse(ncxXML)
            } catch {
                diagnostics.append(
                    EPUBDiagnostic(
                        severity: .info,
                        message: "Unable to parse NCX table of contents: \(error.localizedDescription)",
                        path: ncxPath
                    )
                )
            }
        }

        return EPUBTOC()
    }
}
