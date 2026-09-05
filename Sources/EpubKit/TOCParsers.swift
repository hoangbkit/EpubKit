import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
@preconcurrency import SwiftSoup

struct EPUBTOC: Sendable, Equatable {
    var items: [EPUBTOCItem] = []
    var titlesByPath: [String: String] = [:]

    init(items: [EPUBTOCItem] = []) {
        self.items = items
        index(items)
    }

    func title(forResolvedPath path: String) -> String? {
        titlesByPath[EPUBPathResolver.canonicalForMatching(path)]
    }

    private mutating func index(_ items: [EPUBTOCItem]) {
        for item in items {
            if let href = item.href {
                titlesByPath[EPUBPathResolver.canonicalForMatching(href)] = item.title
            }
            index(item.children)
        }
    }
}

enum NavDocumentParser {
    static func parse(_ html: String, basePath: String) -> EPUBTOC {
        guard let document = try? SwiftSoup.parse(html) else {
            return EPUBTOC()
        }

        let navSelectors = [
            "nav[epub\\:type~='toc']",
            "nav[type~='toc']",
            "nav"
        ]

        var navElement: Element?
        for selector in navSelectors {
            if let elements = try? document.select(selector), let first = elements.array().first {
                navElement = first
                break
            }
        }

        guard let navElement else {
            return EPUBTOC()
        }

        let rootList = directChildList(of: navElement)
            ?? ((try? navElement.select("ol, ul"))?.array().first)

        guard let rootList else {
            return EPUBTOC()
        }

        return EPUBTOC(items: parseList(rootList, basePath: basePath, idPrefix: "nav"))
    }

    private static func parseList(_ list: Element, basePath: String, idPrefix: String) -> [EPUBTOCItem] {
        list.children().array().enumerated().compactMap { index, child in
            guard child.tagName().lowercased() == "li" else { return nil }

            let directChildren = child.children().array()
            let anchor = directChildren.first(where: { $0.tagName().lowercased() == "a" })
                ?? ((try? child.select("a[href]"))?.array().first)
            let labelElement = anchor
                ?? directChildren.first(where: {
                    let tag = $0.tagName().lowercased()
                    return tag == "span" || tag == "div"
                })

            let title = ((try? labelElement?.text()) ?? nil)?.epub_trimmedOrNil
            let rawHref = ((try? anchor?.attr("href")) ?? nil)?.epub_trimmedOrNil
            let href = rawHref.map { EPUBPathResolver.resolve(basePath: basePath, href: $0) }
            let nestedList = directChildren.first(where: {
                let tag = $0.tagName().lowercased()
                return tag == "ol" || tag == "ul"
            })
            let itemID = "\(idPrefix)-\(index)"
            let children = nestedList.map { parseList($0, basePath: basePath, idPrefix: itemID) } ?? []

            guard let title = title ?? href?.epub_trimmedOrNil else {
                return children.isEmpty
                    ? nil
                    : EPUBTOCItem(id: itemID, title: "Section", href: href, children: children)
            }

            return EPUBTOCItem(id: itemID, title: title, href: href, children: children)
        }
    }

    private static func directChildList(of element: Element) -> Element? {
        element.children().array().first {
            let tag = $0.tagName().lowercased()
            return tag == "ol" || tag == "ul"
        }
    }
}

final class NCXParser: NSObject, XMLParserDelegate {
    private struct PendingPoint {
        var id: String
        var label: String?
        var src: String?
        var children: [EPUBTOCItem] = []
    }

    private let basePath: String
    private var currentText = ""
    private var pointStack: [PendingPoint] = []
    private var rootItems: [EPUBTOCItem] = []
    private var pointCounter = 0

    init(basePath: String) {
        self.basePath = basePath
    }

    func parse(_ xml: String) -> EPUBTOC {
        pointStack = []
        rootItems = []
        pointCounter = 0
        currentText = ""

        guard let data = xml.data(using: .utf8) else { return EPUBTOC() }
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = true
        _ = parser.parse()
        return EPUBTOC(items: rootItems)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        let name = XMLName.local(elementName, qName)
        currentText = ""

        if name == "navPoint" {
            pointCounter += 1
            pointStack.append(
                PendingPoint(id: attributeDict["id"] ?? "ncx-\(pointCounter)")
            )
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
            let href = point.src.map { EPUBPathResolver.resolve(basePath: basePath, href: $0) }
            let title = point.label?.epub_trimmedOrNil
                ?? href?.epub_trimmedOrNil
                ?? point.id
            let item = EPUBTOCItem(
                id: point.id,
                title: title,
                href: href,
                children: point.children
            )

            if var parent = pointStack.popLast() {
                parent.children.append(item)
                pointStack.append(parent)
            } else {
                rootItems.append(item)
            }
        }

        currentText = ""
    }
}
