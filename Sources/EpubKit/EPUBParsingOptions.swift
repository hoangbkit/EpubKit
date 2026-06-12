import Foundation

public struct EPUBParsingOptions: Sendable, Equatable {
    public enum WhitespaceMode: Sendable, Equatable {
        case preserveParagraphs
        case compact
    }

    public var whitespaceMode: WhitespaceMode
    public var dropEmptyChapters: Bool
    public var parseTableOfContentsTitles: Bool
    public var detectEncryptedEPUB: Bool
    public var maxEntrySizeBytes: Int
    public var maxTotalExtractedBytes: Int
    public var removeCSSSelectors: [String]

    public init(
        whitespaceMode: WhitespaceMode = .preserveParagraphs,
        dropEmptyChapters: Bool = true,
        parseTableOfContentsTitles: Bool = true,
        detectEncryptedEPUB: Bool = true,
        maxEntrySizeBytes: Int = 30 * 1024 * 1024,
        maxTotalExtractedBytes: Int = 300 * 1024 * 1024,
        removeCSSSelectors: [String] = EPUBParsingOptions.defaultRemoveCSSSelectors
    ) {
        self.whitespaceMode = whitespaceMode
        self.dropEmptyChapters = dropEmptyChapters
        self.parseTableOfContentsTitles = parseTableOfContentsTitles
        self.detectEncryptedEPUB = detectEncryptedEPUB
        self.maxEntrySizeBytes = maxEntrySizeBytes
        self.maxTotalExtractedBytes = maxTotalExtractedBytes
        self.removeCSSSelectors = removeCSSSelectors
    }

    public static let `default` = EPUBParsingOptions()

    public static let defaultRemoveCSSSelectors: [String] = [
        "script",
        "style",
        "nav",
        "aside",
        "header",
        "footer",
        "noscript",
        "svg",
        "canvas",
        "audio",
        "video",
        "math",
        ".pagebreak",
        ".pagenum",
        "[epub|type~='pagebreak']",
        "[role='doc-pagebreak']"
    ]
}

public struct EPUBParsingProgress: Sendable, Equatable {
    public var completedSpineItems: Int
    public var totalSpineItems: Int
    public var currentPath: String?

    public init(completedSpineItems: Int, totalSpineItems: Int, currentPath: String?) {
        self.completedSpineItems = completedSpineItems
        self.totalSpineItems = totalSpineItems
        self.currentPath = currentPath
    }

    public var fractionCompleted: Double {
        guard totalSpineItems > 0 else { return 0 }
        return Double(completedSpineItems) / Double(totalSpineItems)
    }
}
