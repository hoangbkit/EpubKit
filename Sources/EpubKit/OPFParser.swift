import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

struct OPFManifestItem: Sendable, Equatable {
    var id: String
    var href: String
    var mediaType: String
    var properties: [String]
}

struct OPFDocument: Sendable, Equatable {
    var metadata: EPUBMetadata
    var manifest: [String: OPFManifestItem]
    var spine: [String]
    var tocID: String?
}

final class OPFParser: NSObject, XMLParserDelegate {
    private var metadata = EPUBMetadata()
    private var manifest: [String: OPFManifestItem] = [:]
    private var spine: [String] = []
    private var tocID: String?

    private var elementStack: [String] = []
    private var currentText = ""
    private var currentMetaProperty: String?

    func parse(_ xml: String, path: String) throws -> OPFDocument {
        guard let data = xml.data(using: .utf8) else {
            throw EPUBParserError.invalidPackageDocument(path)
        }

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = true

        guard parser.parse() else {
            throw EPUBParserError.invalidPackageDocument(path)
        }
        guard !spine.isEmpty else {
            throw EPUBParserError.missingSpine
        }

        return OPFDocument(metadata: metadata, manifest: manifest, spine: spine, tocID: tocID)
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        let name = XMLName.local(elementName, qName)
        elementStack.append(name)
        currentText = ""
        currentMetaProperty = nil

        switch name {
        case "item":
            guard let id = attributeDict["id"], let href = attributeDict["href"] else { return }
            let mediaType = attributeDict["media-type"] ?? ""
            let properties = attributeDict["properties"]?.split(separator: " ").map(String.init) ?? []
            manifest[id] = OPFManifestItem(id: id, href: href, mediaType: mediaType, properties: properties)

        case "itemref":
            if let idref = attributeDict["idref"], attributeDict["linear"] != "no" {
                spine.append(idref)
            }

        case "spine":
            tocID = attributeDict["toc"]

        case "meta":
            currentMetaProperty = attributeDict["property"]

        default:
            break
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
        let text = currentText.epub_normalizedWhitespace

        switch name {
        case "title":
            if isInsideMetadata, metadata.title == nil, !text.isEmpty {
                metadata.title = text
            }
        case "creator":
            if isInsideMetadata, !text.isEmpty {
                metadata.creators.append(text)
            }
        case "language":
            if isInsideMetadata, metadata.language == nil, !text.isEmpty {
                metadata.language = text
            }
        case "identifier":
            if isInsideMetadata, !text.isEmpty {
                metadata.identifiers.append(text)
            }
        case "publisher":
            if isInsideMetadata, metadata.publisher == nil, !text.isEmpty {
                metadata.publisher = text
            }
        case "meta":
            if isInsideMetadata, !text.isEmpty {
                switch currentMetaProperty {
                case "dcterms:modified":
                    metadata.modified = text
                case "rendition:layout":
                    metadata.renditionLayout = text
                default:
                    break
                }
            }
        default:
            break
        }

        if !elementStack.isEmpty {
            elementStack.removeLast()
        }
        currentText = ""
        currentMetaProperty = nil
    }

    private var isInsideMetadata: Bool {
        elementStack.contains("metadata")
    }
}
