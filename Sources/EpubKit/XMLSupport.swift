import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

enum XMLName {
    static func local(_ name: String) -> String {
        if let colon = name.lastIndex(of: ":") {
            return String(name[name.index(after: colon)...])
        }
        return name
    }

    static func local(_ elementName: String, _ qName: String?) -> String {
        local(qName ?? elementName)
    }
}

extension String {
    var epub_normalizedWhitespace: String {
        replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: #"[ \t\r\n]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var epub_trimmedOrNil: String? {
        let trimmed = epub_normalizedWhitespace
        return trimmed.isEmpty ? nil : trimmed
    }
}
