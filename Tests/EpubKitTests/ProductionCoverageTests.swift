import Foundation
import XCTest
import ZIPFoundation
@testable import EpubKit

final class ProductionCoverageTests: XCTestCase {
    func testEPUB3CoverAndNestedNavAreExposed() throws {
        let coverData = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Nested Book</dc:title>
            <dc:creator>Author</dc:creator>
          </metadata>
          <manifest>
            <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
            <item id="cover" href="images/cover.jpg" media-type="image/jpeg" properties="cover-image"/>
          </manifest>
          <spine><itemref idref="chapter"/></spine>
        </package>
        """
        let nav = """
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
          <body><nav epub:type="toc"><ol>
            <li><span>Part One</span><ol>
              <li><a href="chapter.xhtml">Chapter One</a></li>
            </ol></li>
          </ol></nav></body>
        </html>
        """

        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/nav.xhtml": Data(nav.utf8),
            "OEBPS/chapter.xhtml": Data(chapterHTML(title: "Fallback", body: "Readable chapter text.").utf8),
            "OEBPS/images/cover.jpg": coverData
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.cover?.data, coverData)
        XCTAssertEqual(document.cover?.mediaType, "image/jpeg")
        XCTAssertEqual(document.cover?.href, "OEBPS/images/cover.jpg")
        XCTAssertEqual(document.tableOfContents.count, 1)
        XCTAssertEqual(document.tableOfContents[0].title, "Part One")
        XCTAssertNil(document.tableOfContents[0].href)
        XCTAssertEqual(document.tableOfContents[0].children.first?.title, "Chapter One")
        XCTAssertEqual(document.tableOfContents[0].children.first?.href, "OEBPS/chapter.xhtml")
        XCTAssertEqual(document.chapters.first?.title, "Chapter One")
    }

    func testEPUB2LegacyCoverAndNCXAreExposed() throws {
        let coverData = Data([0x89, 0x50, 0x4E, 0x47])
        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="2.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Legacy Book</dc:title>
            <meta name="cover" content="cover-image"/>
          </metadata>
          <manifest>
            <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
            <item id="cover-image" href="cover.png" media-type="image/png"/>
          </manifest>
          <spine toc="ncx"><itemref idref="chapter"/></spine>
        </package>
        """
        let ncx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <ncx xmlns="http://www.daisy.org/z3986/2005/ncx/">
          <navMap>
            <navPoint id="part"><navLabel><text>Part A</text></navLabel>
              <navPoint id="chapter-one"><navLabel><text>Legacy Chapter</text></navLabel><content src="chapter.xhtml"/></navPoint>
            </navPoint>
          </navMap>
        </ncx>
        """

        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/toc.ncx": Data(ncx.utf8),
            "OEBPS/chapter.xhtml": Data(chapterHTML(title: nil, body: "Legacy readable text.").utf8),
            "OEBPS/cover.png": coverData
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.cover?.data, coverData)
        XCTAssertEqual(document.cover?.mediaType, "image/png")
        XCTAssertEqual(document.tableOfContents.first?.title, "Part A")
        XCTAssertEqual(document.tableOfContents.first?.children.first?.title, "Legacy Chapter")
        XCTAssertEqual(document.chapters.first?.title, "Legacy Chapter")
    }

    func testPercentEncodedSpineHrefReadsDecodedEntry() throws {
        let opf = minimalOPF(manifest: """
            <item id="chapter" href="Chapter%201.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"chapter\"/>")
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/Chapter 1.xhtml": Data(chapterHTML(title: "Encoded", body: "Decoded path works.").utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.chapters.first?.href, "OEBPS/Chapter 1.xhtml")
        XCTAssertTrue(document.chapters.first?.text.contains("Decoded path works.") == true)
    }

    func testMissingSpineManifestItemAddsDiagnosticAndContinues() throws {
        let opf = minimalOPF(manifest: """
            <item id="good" href="good.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"missing\"/><itemref idref=\"good\"/>")
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/good.xhtml": Data(chapterHTML(title: "Good", body: "Still readable.").utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.chapters.count, 1)
        XCTAssertTrue(document.diagnostics.contains { $0.message.contains("missing manifest item") })
    }

    func testMissingChapterEntryAddsDiagnosticAndContinues() throws {
        let opf = minimalOPF(manifest: """
            <item id="missing" href="missing.xhtml" media-type="application/xhtml+xml"/>
            <item id="good" href="good.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"missing\"/><itemref idref=\"good\"/>")
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/good.xhtml": Data(chapterHTML(title: "Good", body: "Second chapter survives.").utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.chapters.count, 1)
        XCTAssertTrue(document.diagnostics.contains { $0.path == "OEBPS/missing.xhtml" })
    }

    func testEncryptionHintDoesNotBlockReadableBook() throws {
        let opf = minimalOPF(manifest: """
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"chapter\"/>")
        let url = try makeEPUB(
            opf: opf,
            entries: [
                "OEBPS/chapter.xhtml": Data(chapterHTML(title: "Readable", body: "Readable despite encryption metadata.").utf8)
            ],
            encryptionXML: "<encryption xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"/>"
        )

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.chapters.count, 1)
        XCTAssertTrue(document.diagnostics.contains { $0.path == "META-INF/encryption.xml" })
    }

    func testFixedLayoutAddsDiagnostic() throws {
        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Fixed</dc:title>
            <meta property="rendition:layout">pre-paginated</meta>
          </metadata>
          <manifest><item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
          <spine><itemref idref="chapter"/></spine>
        </package>
        """
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/chapter.xhtml": Data(chapterHTML(title: "Fixed", body: "Extractable fixed-layout text.").utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertTrue(document.diagnostics.contains { $0.message.contains("fixed-layout") })
    }

    func testMissingCoverIsDiagnosticButDoesNotBlockBook() throws {
        let opf = minimalOPF(manifest: """
            <item id="cover" href="cover.jpg" media-type="image/jpeg" properties="cover-image"/>
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"chapter\"/>")
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/chapter.xhtml": Data(chapterHTML(title: "Chapter", body: "Book remains readable.").utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertNil(document.cover)
        XCTAssertEqual(document.chapters.count, 1)
        XCTAssertTrue(document.diagnostics.contains { $0.message.contains("Unable to load EPUB cover") })
    }

    func testDisablingTOCParsingOmitsPublicTOC() throws {
        let opf = minimalOPF(manifest: """
            <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"chapter\"/>")
        let nav = "<html><body><nav><ol><li><a href=\"chapter.xhtml\">TOC Title</a></li></ol></nav></body></html>"
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/nav.xhtml": Data(nav.utf8),
            "OEBPS/chapter.xhtml": Data(chapterHTML(title: "HTML Title", body: "Readable.").utf8)
        ])

        let document = try EPUBParser().parse(
            fileURL: url,
            options: EPUBParsingOptions(parseTableOfContentsTitles: false)
        )

        XCTAssertTrue(document.tableOfContents.isEmpty)
        XCTAssertEqual(document.chapters.first?.title, "HTML Title")
    }

    private func makeEPUB(
        opf: String,
        entries: [String: Data],
        encryptionXML: String? = nil
    ) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("epub")
        let archive = try Archive(url: url, accessMode: .create)

        var allEntries: [String: Data] = [
            "mimetype": Data("application/epub+zip".utf8),
            "META-INF/container.xml": Data(containerXML.utf8),
            "OEBPS/content.opf": Data(opf.utf8)
        ]
        entries.forEach { allEntries[$0.key] = $0.value }
        if let encryptionXML {
            allEntries["META-INF/encryption.xml"] = Data(encryptionXML.utf8)
        }

        for path in allEntries.keys.sorted() {
            let data = try XCTUnwrap(allEntries[path])
            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: Int64(data.count),
                provider: { position, size in
                    let start = Int(position)
                    return data.subdata(in: start..<(start + size))
                }
            )
        }

        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private var containerXML: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles>
        </container>
        """
    }

    private func minimalOPF(manifest: String, spine: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Test Book</dc:title></metadata>
          <manifest>\(manifest)</manifest>
          <spine>\(spine)</spine>
        </package>
        """
    }

    private func chapterHTML(title: String?, body: String) -> String {
        let titleElement = title.map { "<title>\($0)</title>" } ?? ""
        return "<html><head>\(titleElement)</head><body><p>\(body)</p></body></html>"
    }
}
