import Foundation
import XCTest
@testable import EpubKit

final class HardeningCoverageTests: XCTestCase {
    func testMissingContainerThrows() throws {
        let url = try makeArchive(entries: [
            "mimetype": Data("application/epub+zip".utf8)
        ])

        assertParserError(.missingContainer, parsing: url)
    }

    func testInvalidContainerThrows() throws {
        let url = try makeArchive(entries: [
            "META-INF/container.xml": Data("<container><rootfiles>".utf8)
        ])

        assertParserError(.invalidContainer, parsing: url)
    }

    func testMissingPackageDocumentThrows() throws {
        let container = containerXML(packagePath: "OEBPS/missing.opf")
        let url = try makeArchive(entries: [
            "META-INF/container.xml": Data(container.utf8)
        ])

        assertParserError(.missingPackageDocument("OEBPS/missing.opf"), parsing: url)
    }

    func testFirstRootFileWinsWhenContainerListsSeveral() throws {
        let container = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles>
            <rootfile full-path="OEBPS/first.opf" media-type="application/oebps-package+xml"/>
            <rootfile full-path="OEBPS/second.opf" media-type="application/oebps-package+xml"/>
          </rootfiles>
        </container>
        """
        let firstOPF = minimalOPF(manifest: """
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"chapter\"/>")
        let secondOPF = minimalOPF(manifest: """
            <item id="other" href="other.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"other\"/>")
        let url = try makeArchive(entries: [
            "mimetype": Data("application/epub+zip".utf8),
            "META-INF/container.xml": Data(container.utf8),
            "OEBPS/first.opf": Data(firstOPF.utf8),
            "OEBPS/second.opf": Data(secondOPF.utf8),
            "OEBPS/chapter.xhtml": Data(chapterHTML(title: nil, body: "First rootfile content.").utf8),
            "OEBPS/other.xhtml": Data(chapterHTML(title: nil, body: "Second rootfile content.").utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.chapters.count, 1)
        XCTAssertEqual(document.chapters.first?.href, "OEBPS/chapter.xhtml")
    }

    func testInvalidPackageDocumentThrows() throws {
        let url = try makeEPUB(opf: "<package><metadata>")

        assertParserError(.invalidPackageDocument("OEBPS/content.opf"), parsing: url)
    }

    func testMissingSpineThrows() throws {
        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>No Spine</dc:title></metadata>
          <manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
          <spine></spine>
        </package>
        """
        let url = try makeEPUB(opf: opf)

        assertParserError(.missingSpine, parsing: url)
    }

    func testNoReadableContentThrows() throws {
        let opf = minimalOPF(
            manifest: "<item id=\"image\" href=\"image.png\" media-type=\"image/png\"/>",
            spine: "<itemref idref=\"image\"/>"
        )
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/image.png": Data([0x89, 0x50, 0x4E, 0x47])
        ])

        assertParserError(.noReadableContent, parsing: url)
    }

    func testEncryptedBookWithoutReadableContentThrowsEncryptedError() throws {
        let opf = minimalOPF(
            manifest: "<item id=\"image\" href=\"image.png\" media-type=\"image/png\"/>",
            spine: "<itemref idref=\"image\"/>"
        )
        let url = try makeEPUB(
            opf: opf,
            entries: ["OEBPS/image.png": Data([0x89, 0x50, 0x4E, 0x47])],
            encryptionXML: "<encryption xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"/>"
        )

        assertParserError(.encryptedEPUB, parsing: url)
    }

    func testUnsafeArchivePathIsRejected() throws {
        let url = try makeArchive(entries: [
            "payload.txt": Data("safe".utf8)
        ])
        let reader = try ArchiveDataReader(fileURL: url, options: .default)

        XCTAssertThrowsError(try reader.readData("../payload.txt")) { error in
            XCTAssertEqual(error as? EPUBParserError, .unsafeArchivePath("../payload.txt"))
        }
        XCTAssertThrowsError(try reader.readData("/payload.txt")) { error in
            XCTAssertEqual(error as? EPUBParserError, .unsafeArchivePath("/payload.txt"))
        }
        XCTAssertThrowsError(try reader.readData("folder\\payload.txt")) { error in
            XCTAssertEqual(error as? EPUBParserError, .unsafeArchivePath("folder\\payload.txt"))
        }
    }

    func testEntrySizeLimitIsEnforced() throws {
        let url = try makeArchive(entries: [
            "large.bin": Data(repeating: 0x41, count: 128)
        ])
        let options = EPUBParsingOptions(maxEntrySizeBytes: 64, maxTotalExtractedBytes: 1024)
        let reader = try ArchiveDataReader(fileURL: url, options: options)

        XCTAssertThrowsError(try reader.readData("large.bin")) { error in
            XCTAssertEqual(error as? EPUBParserError, .entryTooLarge(path: "large.bin", limit: 64))
        }
    }

    func testTotalExtractionLimitIsEnforcedAcrossEntries() throws {
        let url = try makeArchive(entries: [
            "one.bin": Data(repeating: 0x41, count: 40),
            "two.bin": Data(repeating: 0x42, count: 40)
        ])
        let options = EPUBParsingOptions(maxEntrySizeBytes: 128, maxTotalExtractedBytes: 64)
        let reader = try ArchiveDataReader(fileURL: url, options: options)

        XCTAssertEqual(try reader.readData("one.bin").count, 40)
        XCTAssertThrowsError(try reader.readData("two.bin")) { error in
            XCTAssertEqual(error as? EPUBParserError, .archiveTooLarge(limit: 64))
        }
    }

    func testUTF16AndLatin1TextDecoding() throws {
        let utf16 = try XCTUnwrap("Hello UTF-16".data(using: .utf16))
        let latin1 = try XCTUnwrap("café".data(using: .isoLatin1))
        let url = try makeArchive(entries: [
            "utf16.txt": utf16,
            "latin1.txt": latin1
        ])
        let reader = try ArchiveDataReader(fileURL: url, options: .default)

        XCTAssertEqual(try reader.readString("utf16.txt"), "Hello UTF-16")
        XCTAssertEqual(try reader.readString("latin1.txt"), "café")
    }

    func testBOMLessUTF16TextDecoding() throws {
        // "Hello" as UTF-16 little-endian without a BOM: the null-byte
        // heuristic in ArchiveDataReader must pick little-endian here.
        let utf16LE = Data([0x48, 0x00, 0x65, 0x00, 0x6C, 0x00, 0x6C, 0x00, 0x6F, 0x00])
        let url = try makeArchive(entries: ["bomless.txt": utf16LE])
        let reader = try ArchiveDataReader(fileURL: url, options: .default)

        XCTAssertEqual(try reader.readString("bomless.txt"), "Hello")
    }

    func testCorruptArchiveThrowsUnreadableArchive() throws {
        let url = try makeArchive(entries: ["note.txt": Data("not a zip".utf8)])
        // Overwrite the file so Archive(url:accessMode:.read) fails on its header.
        try Data(repeating: 0x00, count: 512).write(to: url)

        XCTAssertThrowsError(try EPUBParser().parse(fileURL: url)) { error in
            XCTAssertEqual(error as? EPUBParserError, .unreadableArchive(url))
        }
    }

    func testMissingFileThrowsFileDoesNotExist() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString).epub")

        XCTAssertThrowsError(try EPUBParser().parse(fileURL: url)) { error in
            XCTAssertEqual(error as? EPUBParserError, .fileDoesNotExist(url))
        }
    }

    func testDropEmptyChaptersFalsePreservesChapter() throws {
        let opf = minimalOPF(
            manifest: "<item id=\"empty\" href=\"empty.xhtml\" media-type=\"application/xhtml+xml\"/>",
            spine: "<itemref idref=\"empty\"/>"
        )
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/empty.xhtml": Data("<html><head><title>Empty</title></head><body><p>   </p></body></html>".utf8)
        ])
        let options = EPUBParsingOptions(dropEmptyChapters: false)

        let document = try EPUBParser().parse(fileURL: url, options: options)

        XCTAssertEqual(document.chapters.count, 1)
        XCTAssertEqual(document.chapters[0].title, "Empty")
        XCTAssertTrue(document.chapters[0].text.isEmpty)
    }

    func testCustomRemovalSelectorIsApplied() throws {
        let opf = minimalOPF(
            manifest: "<item id=\"chapter\" href=\"chapter.xhtml\" media-type=\"application/xhtml+xml\"/>",
            spine: "<itemref idref=\"chapter\"/>"
        )
        let html = "<html><body><p class=\"promo\">Remove me</p><p>Keep me</p></body></html>"
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/chapter.xhtml": Data(html.utf8)
        ])
        let options = EPUBParsingOptions(removeCSSSelectors: [".promo"])

        let document = try EPUBParser().parse(fileURL: url, options: options)

        XCTAssertFalse(document.chapters[0].text.contains("Remove me"))
        XCTAssertTrue(document.chapters[0].text.contains("Keep me"))
    }

    func testMalformedHTMLIsRecovered() throws {
        let opf = minimalOPF(
            manifest: "<item id=\"chapter\" href=\"chapter.xhtml\" media-type=\"application/xhtml+xml\"/>",
            spine: "<itemref idref=\"chapter\"/>"
        )
        let malformedHTML = "<html><head><title>Broken</title></head><body><p>First paragraph<p>Second paragraph"
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/chapter.xhtml": Data(malformedHTML.utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.chapters.first?.title, "Broken")
        XCTAssertTrue(document.chapters.first?.text.contains("First paragraph") == true)
        XCTAssertTrue(document.chapters.first?.text.contains("Second paragraph") == true)
    }

    func testMetadataFieldsAreParsed() throws {
        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Metadata Book</dc:title>
            <dc:creator>Author One</dc:creator>
            <dc:creator>Author Two</dc:creator>
            <dc:language>en</dc:language>
            <dc:identifier>urn:isbn:123</dc:identifier>
            <dc:identifier>book-id</dc:identifier>
            <dc:publisher>Publisher</dc:publisher>
            <meta property="dcterms:modified">2026-09-05T00:00:00Z</meta>
          </metadata>
          <manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
          <spine><itemref idref="chapter"/></spine>
        </package>
        """
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/chapter.xhtml": Data("<html><body><p>Readable.</p></body></html>".utf8)
        ])

        let metadata = try EPUBParser().parse(fileURL: url).metadata

        XCTAssertEqual(metadata.title, "Metadata Book")
        XCTAssertEqual(metadata.creators, ["Author One", "Author Two"])
        XCTAssertEqual(metadata.language, "en")
        XCTAssertEqual(metadata.identifiers, ["urn:isbn:123", "book-id"])
        XCTAssertEqual(metadata.publisher, "Publisher")
        XCTAssertEqual(metadata.modified, "2026-09-05T00:00:00Z")
    }

    func testMissingNavFallsBackToNCX() throws {
        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Fallback</dc:title></metadata>
          <manifest>
            <item id="nav" href="missing-nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine toc="ncx"><itemref idref="chapter"/></spine>
        </package>
        """
        let ncx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/">
          <navMap><navPoint id="chapter"><navLabel><text>NCX Title</text></navLabel><content src="chapter.xhtml"/></navPoint></navMap>
        </ncx>
        """
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/toc.ncx": Data(ncx.utf8),
            "OEBPS/chapter.xhtml": Data("<html><head><title>HTML Title</title></head><body><p>Readable.</p></body></html>".utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.tableOfContents.first?.title, "NCX Title")
        XCTAssertEqual(document.chapters.first?.title, "NCX Title")
        XCTAssertTrue(document.diagnostics.contains { $0.path == "OEBPS/missing-nav.xhtml" })
    }

    func testParseAsyncReturnsDocument() async throws {
        let opf = minimalOPF(
            manifest: "<item id=\"chapter\" href=\"chapter.xhtml\" media-type=\"application/xhtml+xml\"/>",
            spine: "<itemref idref=\"chapter\"/>"
        )
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/chapter.xhtml": Data("<html><body><p>Async readable.</p></body></html>".utf8)
        ])

        let document = try await EPUBParser().parseAsync(fileURL: url)

        XCTAssertEqual(document.chapters.count, 1)
        XCTAssertTrue(document.plainText.contains("Async readable."))
    }

    func testParseAsyncCancellationThrowsParserCancelled() async throws {
        // Build a book with enough spine items that the parse is still running
        // when the cancellation lands; a one-chapter book can finish before
        // cancellation is observed and the test would flake.
        let manifest = (0..<200).map { index in
            "<item id=\"c\(index)\" href=\"c\(index).xhtml\" media-type=\"application/xhtml+xml\"/>"
        }.joined()
        let spine = (0..<200).map { "<itemref idref=\"c\($0)\"/>" }.joined()
        let entries = (0..<200).reduce(into: [:]) { result, index in
            result["OEBPS/c\(index).xhtml"] = Data(chapterHTML(title: nil, body: "Chapter \(index) text.").utf8)
        }
        let url = try makeEPUB(opf: minimalOPF(manifest: manifest, spine: spine), entries: entries)

        // The onProgress callback runs synchronously inside the detached
        // parsing task, so a captured cancellation trigger fired from the
        // first progress callback is guaranteed to be seen at the next spine
        // item's checkCancellation — no race with task completion.
        let cancellable = CancelTaskHandle()
        let task = Task {
            try await EPUBParser().parseAsync(
                fileURL: url,
                options: .default,
                onProgress: { progress in
                    if progress.completedSpineItems >= 1 {
                        cancellable.cancel()
                    }
                }
            )
        }
        cancellable.target = task

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch let error as EPUBParserError {
            XCTAssertEqual(error, .cancelled)
        } catch {
            XCTFail("Expected EPUBParserError.cancelled, got \(error)")
        }
    }

    private func assertParserError(
        _ expected: EPUBParserError,
        parsing url: URL,
        options: EPUBParsingOptions = .default,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            _ = try EPUBParser().parse(fileURL: url, options: options)
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let error as EPUBParserError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Expected EPUBParserError, got \(error)", file: file, line: line)
        }
    }
}
