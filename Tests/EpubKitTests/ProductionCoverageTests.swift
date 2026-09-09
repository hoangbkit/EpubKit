import Foundation
import XCTest
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

    func testTextHTMLSpineItemsAreReadable() throws {
        // EPUB2-era books commonly use text/html media types and .html files.
        let manifest = """
            <item id="media-html" href="a.html" media-type="text/html"/>
            <item id="ext-html" href="b.html" media-type="application/octet-stream"/>
            <item id="ext-htm" href="c.htm" media-type=""/>
            <item id="app-html" href="d.html" media-type="application/html"/>
            <item id="image" href="image.png" media-type="image/png"/>
        """
        let spine = """
            <itemref idref="media-html"/><itemref idref="ext-html"/>
            <itemref idref="ext-htm"/><itemref idref="app-html"/>
            <itemref idref="image"/>
        """
        let opf = minimalOPF(manifest: manifest, spine: spine)
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/a.html": Data(chapterHTML(title: nil, body: "Media type html.").utf8),
            "OEBPS/b.html": Data(chapterHTML(title: nil, body: "Extension html.").utf8),
            "OEBPS/c.htm": Data(chapterHTML(title: nil, body: "Extension htm.").utf8),
            "OEBPS/d.html": Data(chapterHTML(title: nil, body: "Application html.").utf8),
            "OEBPS/image.png": Data([0x89, 0x50, 0x4E, 0x47])
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.chapters.map(\.order), [0, 1, 2, 3])
        XCTAssertEqual(document.chapters[0].id, "media-html")
        XCTAssertEqual(document.chapters[1].id, "ext-html")
        XCTAssertEqual(document.chapters[2].id, "ext-htm")
        XCTAssertEqual(document.chapters[3].id, "app-html")
        XCTAssertTrue(document.plainText.contains("Media type html."))
        // The image spine item must not leak in as a chapter.
        XCTAssertFalse(document.plainText.contains("PNG"))
    }

    func testPercentEncodedPackageDocumentPathResolves() throws {
        // container.xml references "content%201.opf" (percent-encoded, as the
        // OCF spec requires) while the zip entry is stored decoded as
        // "content 1.opf". readData's fallback handles this, but contains()
        // historically did not — so the parse died with a misleading
        // missingPackageDocument error before ever attempting to read.
        let opf = minimalOPF(manifest: """
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"chapter\"/>")
        let opfData = Data(opf.utf8)
        let url = try makeArchive(entries: [
            "mimetype": Data("application/epub+zip".utf8),
            "META-INF/container.xml": Data(containerXML(packagePath: "OEBPS/content%201.opf").utf8),
            "OEBPS/content 1.opf": opfData,
            "OEBPS/chapter.xhtml": Data(chapterHTML(title: nil, body: "Encoded OPF readable.").utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.chapters.count, 1)
        XCTAssertTrue(document.plainText.contains("Encoded OPF readable."))
    }

    func testDetectEncryptedEPUBFalseIgnoresEncryptionHint() throws {
        // A book with encryption.xml but no readable content must fail with
        // the generic error (not encryptedEPUB) when detection is disabled.
        let opf = minimalOPF(
            manifest: "<item id=\"image\" href=\"image.png\" media-type=\"image/png\"/>",
            spine: "<itemref idref=\"image\"/>"
        )
        let url = try makeEPUB(
            opf: opf,
            entries: ["OEBPS/image.png": Data([0x89, 0x50, 0x4E, 0x47])],
            encryptionXML: "<encryption xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"/>"
        )
        let options = EPUBParsingOptions(detectEncryptedEPUB: false)

        do {
            _ = try EPUBParser().parse(fileURL: url, options: options)
            XCTFail("Expected noReadableContent")
        } catch let error as EPUBParserError {
            XCTAssertEqual(error, .noReadableContent)
        }
    }

    func testReadableSectionsMirrorChapters() throws {
        let opf = minimalOPF(manifest: """
            <item id="one" href="one.xhtml" media-type="application/xhtml+xml"/>
            <item id="two" href="two.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"one\"/><itemref idref=\"two\"/>")
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/one.xhtml": Data(chapterHTML(title: "First", body: "Section one.").utf8),
            "OEBPS/two.xhtml": Data(chapterHTML(title: "Second", body: "Section two.").utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)
        let sections = document.readableSections

        XCTAssertEqual(sections.count, document.chapters.count)
        XCTAssertEqual(sections.map(\.id), document.chapters.map(\.id))
        XCTAssertEqual(sections.map(\.title), document.chapters.map(\.title))
        XCTAssertEqual(sections.map(\.text), document.chapters.map(\.text))
        XCTAssertEqual(sections.map(\.sourcePath), document.chapters.map(\.href))
        XCTAssertEqual(sections.map(\.order), [0, 1])
    }

    func testLinearNoSpineItemsAreSkipped() throws {        let manifest = """
            <item id="pagebreak" href="pagebreak.xhtml" media-type="application/xhtml+xml"/>
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        """
        let url = try makeEPUB(opf: minimalOPF(
            manifest: manifest,
            spine: "<itemref idref=\"pagebreak\" linear=\"no\"/><itemref idref=\"chapter\"/>"
        ), entries: [
            "OEBPS/pagebreak.xhtml": Data(chapterHTML(title: nil, body: "Page break chapter.").utf8),
            "OEBPS/chapter.xhtml": Data(chapterHTML(title: nil, body: "Linear chapter.").utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.chapters.count, 1)
        XCTAssertEqual(document.chapters.first?.id, "chapter")
        XCTAssertEqual(document.chapters.first?.order, 0)
        XCTAssertTrue(document.chapters.first?.text.contains("Linear chapter.") == true)
    }

    func testParentDirectoryHrefsResolveWithinArchive() throws {
        // OPF at OEBPS/content.opf referencing shared content one level up.
        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Shared</dc:title></metadata>
          <manifest><item id="chapter" href="../shared/chapter.xhtml" media-type="application/xhtml+xml"/></manifest>
          <spine><itemref idref="chapter"/></spine>
        </package>
        """
        let url = try makeEPUB(opf: opf, entries: [
            "shared/chapter.xhtml": Data(chapterHTML(title: "Shared", body: "Parent directory href.").utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.chapters.count, 1)
        XCTAssertEqual(document.chapters.first?.href, "shared/chapter.xhtml")
        XCTAssertTrue(document.chapters.first?.text.contains("Parent directory href.") == true)
    }

    func testTOCHrefWithFragmentMatchesChapterTitle() throws {
        let opf = minimalOPF(manifest: """
            <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"chapter\"/>")
        let nav = """
        <html><body><nav><ol>
          <li><a href="chapter.xhtml#section-two">Chapter Title</a></li>
        </ol></nav></body></html>
        """
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/nav.xhtml": Data(nav.utf8),
            "OEBPS/chapter.xhtml": Data(chapterHTML(title: "HTML Title", body: "Readable.").utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.tableOfContents.first?.href, "OEBPS/chapter.xhtml")
        // The nav title must win over the document's <title> despite the fragment.
        XCTAssertEqual(document.chapters.first?.title, "Chapter Title")
    }

    func testLandmarksNavIsNotTreatedAsTOC() throws {
        let opf = minimalOPF(manifest: """
            <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"chapter\"/>")
        let nav = """
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
          <body>
            <nav epub:type="landmarks"><ol>
              <li><a epub:type="bodymatter" href="chapter.xhtml">Start Reading</a></li>
            </ol></nav>
            <nav epub:type="toc"><ol>
              <li><a href="chapter.xhtml">TOC Chapter</a></li>
            </ol></nav>
          </body>
        </html>
        """
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/nav.xhtml": Data(nav.utf8),
            "OEBPS/chapter.xhtml": Data(chapterHTML(title: "HTML Title", body: "Readable.").utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.tableOfContents.count, 1)
        XCTAssertEqual(document.tableOfContents.first?.title, "TOC Chapter")
    }

    func testCoverMetadataPointingAtNonImageAddsDiagnostic() throws {
        let opf = """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="2.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:title>Wrong Cover</dc:title>
            <meta name="cover" content="cover-item"/>
          </metadata>
          <manifest>
            <item id="cover-item" href="cover.xhtml" media-type="application/xhtml+xml"/>
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine><itemref idref="chapter"/></spine>
        </package>
        """
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/cover.xhtml": Data(chapterHTML(title: "Not a cover", body: "XHTML.").utf8),
            "OEBPS/chapter.xhtml": Data(chapterHTML(title: "Chapter", body: "Readable.").utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertNil(document.cover)
        XCTAssertTrue(document.diagnostics.contains { $0.message.contains("non-image") })
    }

    func testChapterWithoutAnyTitleFallsBackToIDRef() throws {
        let opf = minimalOPF(manifest: """
            <item id="untitled-chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"untitled-chapter\"/>")
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/chapter.xhtml": Data("<html><body><p>No title anywhere.</p></body></html>".utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.chapters.first?.title, "untitled-chapter")
    }

    func testDuplicateShortBlocksAreDeduplicated() throws {
        let opf = minimalOPF(manifest: """
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"chapter\"/>")
        // A repeated short heading: the second identical block must be dropped.
        let html = """
        <html><body>
          <h1>Same Heading</h1>
          <p>Body text.</p>
          <h1>Same Heading</h1>
          <p>More body text.</p>
        </body></html>
        """
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/chapter.xhtml": Data(html.utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.chapters.first?.text.components(separatedBy: "\n\n").count, 3)
    }

    func testLongRepeatedBlocksAreKept() throws {
        let opf = minimalOPF(manifest: """
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"chapter\"/>")
        // 120+ chars of identical text in two blocks: dedup must not apply.
        let longText = String(repeating: "This long repeated passage stays. ", count: 5).trimmingCharacters(in: .whitespaces)
        let html = """
        <html><body>
          <p>\(longText)</p>
          <p>\(longText)</p>
        </body></html>
        """
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/chapter.xhtml": Data(html.utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertTrue(document.chapters.first?.text.components(separatedBy: "\n\n").count == 2)
    }

    func testHeadingTitleTakesPriorityOverTitleTag() throws {
        let opf = minimalOPF(manifest: """
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"chapter\"/>")
        // h1 must win over <title>; h2 only when no h1 exists.
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/chapter.xhtml": Data("""
            <html><head><title>Title Tag</title></head>
            <body><h1>First Heading</h1><p>Body.</p></body></html>
            """.utf8)
        ])
        let h2URL = try makeEPUB(opf: opf, entries: [
            "OEBPS/chapter.xhtml": Data("""
            <html><head><title>Title Tag</title></head>
            <body><h2>Second Heading</h2><p>Body.</p></body></html>
            """.utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)
        let h2Document = try EPUBParser().parse(fileURL: h2URL)

        XCTAssertEqual(document.chapters.first?.title, "First Heading")
        XCTAssertEqual(h2Document.chapters.first?.title, "Second Heading")
    }

    func testBlockElementsBecomeParagraphs() throws {
        let opf = minimalOPF(manifest: """
            <item id="chapter" href="chapter.xhtml" media-type="application/xhtml+xml"/>
        """, spine: "<itemref idref=\"chapter\"/>")
        // pre keeps its own line breaks; other blocks each become a paragraph.
        let html = """
        <html><body>
          <p>Regular paragraph.</p>
          <ul><li>List item one.</li><li>List item two.</li></ul>
          <blockquote>Quoted material.</blockquote>
          <pre>line one\nline two</pre>
        </body></html>
        """
        let url = try makeEPUB(opf: opf, entries: [
            "OEBPS/chapter.xhtml": Data(html.utf8)
        ])

        let document = try EPUBParser().parse(fileURL: url)
        let paragraphs = document.chapters.first?.text.components(separatedBy: "\n\n") ?? []

        XCTAssertEqual(paragraphs.count, 5)
        XCTAssertEqual(paragraphs[0], "Regular paragraph.")
        XCTAssertEqual(paragraphs[1], "List item one.")
        XCTAssertEqual(paragraphs[2], "List item two.")
        XCTAssertEqual(paragraphs[3], "Quoted material.")
        XCTAssertTrue(paragraphs[4].contains("line one\nline two"))
    }

    func testArbitraryBytesAlwaysDecodeToSomeText() throws {
        // Latin-1 is the terminal fallback: any entry readable as Data must
        // come back as *some* string, never an unsupportedTextEncoding error.
        let bytes = Data([
            0xFF, 0xFE, 0x00, 0x42, 0xC3, 0x28, 0x81, 0x9F, 0x00, 0x7F, 0x8D, 0xA4
        ])
        let url = try makeArchive(entries: ["garbage.bin": bytes])
        let reader = try ArchiveDataReader(fileURL: url, options: .default)

        XCTAssertNoThrow(try reader.readString("garbage.bin"))
    }
}

