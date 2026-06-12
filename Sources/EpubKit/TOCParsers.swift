import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
@preconcurrency import SwiftSoup

struct EPUBTOC: Sendable, Equatable {
    var titlesByPath: [String: String] = [:]

    func title(forResolvedPath path: String) -> String? {
        titlesByPath[EPUBPathResolver.canonicalForMatching(path)]
    }
}

enum NavDocumentParser {
    static func parse(_ html: String, basePath: String) -> EPUBTOC {
        var toc = EPUBTOC()

        guard let document = try? SwiftSoup.parse(html) else {
            return toc
        }

        let selectors = [
            "nav[epub\\:type~='toc'] a[href]",
            "nav[type~='toc'] a[href]",
            "nav a[href]",
            "a[href]"
        ]

        for selector in selectors {
            guard let anchors = try? document.select(selector), !anchors.isEmpty() else { continue }

            for anchor in anchors.array() {
                guard
                    let href = try? anchor.attr("href"),
                    !href.isEmpty,
                    let title = try? anchor.text(),
                    let cleanTitle = title.epub_trimmedOrNil
                else { continue }

                let resolved = EPUBPathResolver.resolve(basePath: basePath, href: href)
                toc.titlesByPath[EPUBPathResolver.canonicalForMatching(resolved)] = cleanTitle
            }
            break
        }

        return toc
    }
}

final class NCXParser: NSObject, XMLParserDelegate {
    private struct PendingPoint {
        var label: String?
        var src: String?
    }

    private let basePath: String
    private var currentElement: String?
    private var currentText = ""
    private var pointStack: [PendingPoint] = []
    private var toc = EPUBTOC()

    init(basePath: String) {
        self.basePath = basePath
    }

    func parse(_ xml: String) -> EPUBTOC {
        guard let data = xml.data(using: .utf8) else { return EPUBTOC() }
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = true
        _ = parser.parse()
        return toc
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        let name = XMLName.local(elementName, qName)
        currentElement = name
        currentText = ""

        if name == "navPoint" {
            pointStack.append(PendingPoint())
        }

        if name == "content", var point = pointStack.popLast() {
            point.src = attributeDict["src"]
            pointStack.append(point)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = XMLName.local(elementName, qName)

        if name == "text", var point = pointStack.popLast() {
            point.label = currentText.epub_trimmedOrNil ?? point.label
            pointStack.append(point)
        }

        if name == "navPoint", let point = pointStack.popLast() {
            if let src = point.src, let label = point.label {
                let resolved = EPUBPathResolver.resolve(basePath: basePath, href: src)
                toc.titlesByPath[EPUBPathResolver.canonicalForMatching(resolved)] = label
            }
        }

        currentElement = nil
        currentText = ""
    }
}
