import Foundation
@preconcurrency import SwiftSoup

struct ExtractedHTMLText: Sendable, Equatable {
    var title: String?
    var text: String
}

enum HTMLTextExtractor {
    static func extract(
        html: String,
        path: String,
        options: EPUBParsingOptions
    ) throws -> ExtractedHTMLText {
        let document = try SwiftSoup.parse(html)

        for selector in options.removeCSSSelectors {
            if let elements = try? document.select(selector) {
                try? elements.remove()
            }
        }

        let title = firstNonEmptyText(in: document, selectors: [
            "body h1",
            "body h2",
            "body [role='doc-title']",
            "title"
        ])

        let text: String
        switch options.whitespaceMode {
        case .compact:
            text = try compactText(from: document)
        case .preserveParagraphs:
            text = try paragraphText(from: document)
        }

        return ExtractedHTMLText(title: title, text: text)
    }

    private static func firstNonEmptyText(in document: Document, selectors: [String]) -> String? {
        for selector in selectors {
            guard let element = try? document.select(selector).first() else { continue }
            guard let text = try? element.text(), let clean = text.epub_trimmedOrNil else { continue }
            return clean
        }
        return nil
    }

    private static func compactText(from document: Document) throws -> String {
        let body = try document.body()
        let raw = try body?.text() ?? document.text()
        return raw.epub_normalizedWhitespace
    }

    private static func paragraphText(from document: Document) throws -> String {
        guard let body = try document.body() else {
            return try document.text().epub_normalizedWhitespace
        }

        let blockSelector = [
            "h1", "h2", "h3", "h4", "h5", "h6",
            "p", "li", "blockquote", "pre",
            "figcaption", "caption"
        ].joined(separator: ",")

        let blocks = try body.select(blockSelector).array()
        var paragraphs: [String] = []
        var seen = Set<String>()

        for block in blocks {
            let text: String
            if block.tagName() == "pre" {
                text = try block.text().trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                text = try block.text().epub_normalizedWhitespace
            }

            guard !text.isEmpty else { continue }

            // Avoid obvious duplicate heading/title emission from malformed EPUBs.
            let key = text.lowercased()
            if seen.contains(key), text.count < 120 { continue }
            seen.insert(key)

            paragraphs.append(text)
        }

        if paragraphs.isEmpty {
            return try compactText(from: document)
        }

        return paragraphs.joined(separator: "\n\n")
    }
}
