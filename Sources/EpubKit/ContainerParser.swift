import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

final class ContainerParser: NSObject, XMLParserDelegate {
    private var packagePath: String?

    func parse(_ xml: String) throws -> String {
        guard let data = xml.data(using: .utf8) else {
            throw EPUBParserError.invalidContainer
        }

        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldProcessNamespaces = false
        parser.shouldReportNamespacePrefixes = true

        guard parser.parse(), let packagePath else {
            throw EPUBParserError.invalidContainer
        }

        return packagePath
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String]
    ) {
        let name = XMLName.local(elementName, qName)
        guard name == "rootfile" else { return }

        if packagePath == nil {
            packagePath = attributeDict["full-path"]
        }
    }
}
