import Foundation

public struct EPUBDocument: Sendable, Equatable {
    public var metadata: EPUBMetadata
    public var chapters: [EPUBChapter]
    public var cover: EPUBCover?
    public var tableOfContents: [EPUBTOCItem]
    public var diagnostics: [EPUBDiagnostic]

    public init(
        metadata: EPUBMetadata = EPUBMetadata(),
        chapters: [EPUBChapter] = [],
        cover: EPUBCover? = nil,
        tableOfContents: [EPUBTOCItem] = [],
        diagnostics: [EPUBDiagnostic] = []
    ) {
        self.metadata = metadata
        self.chapters = chapters
        self.cover = cover
        self.tableOfContents = tableOfContents
        self.diagnostics = diagnostics
    }

    public var plainText: String {
        chapters.map(\.text).joined(separator: "\n\n")
    }
}

public struct EPUBCover: Sendable, Equatable {
    public var data: Data
    public var mediaType: String
    public var href: String

    public init(data: Data, mediaType: String, href: String) {
        self.data = data
        self.mediaType = mediaType
        self.href = href
    }
}

public struct EPUBTOCItem: Identifiable, Sendable, Equatable {
    public var id: String
    public var title: String
    public var href: String?
    public var children: [EPUBTOCItem]

    public init(
        id: String,
        title: String,
        href: String? = nil,
        children: [EPUBTOCItem] = []
    ) {
        self.id = id
        self.title = title
        self.href = href
        self.children = children
    }
}

public struct EPUBMetadata: Sendable, Equatable {
    public var title: String?
    public var creators: [String]
    public var language: String?
    public var identifiers: [String]
    public var publisher: String?
    public var modified: String?
    public var renditionLayout: String?

    public init(
        title: String? = nil,
        creators: [String] = [],
        language: String? = nil,
        identifiers: [String] = [],
        publisher: String? = nil,
        modified: String? = nil,
        renditionLayout: String? = nil
    ) {
        self.title = title
        self.creators = creators
        self.language = language
        self.identifiers = identifiers
        self.publisher = publisher
        self.modified = modified
        self.renditionLayout = renditionLayout
    }
}

public struct EPUBChapter: Identifiable, Sendable, Equatable {
    public var id: String
    public var order: Int
    public var title: String?
    public var href: String
    public var mediaType: String
    public var properties: [String]
    public var text: String
    public var characterCount: Int { text.count }

    public init(
        id: String,
        order: Int,
        title: String? = nil,
        href: String,
        mediaType: String,
        properties: [String] = [],
        text: String
    ) {
        self.id = id
        self.order = order
        self.title = title
        self.href = href
        self.mediaType = mediaType
        self.properties = properties
        self.text = text
    }
}

public struct EPUBDiagnostic: Sendable, Equatable {
    public enum Severity: String, Sendable, Equatable {
        case info
        case warning
        case error
    }

    public var severity: Severity
    public var message: String
    public var path: String?

    public init(severity: Severity, message: String, path: String? = nil) {
        self.severity = severity
        self.message = message
        self.path = path
    }
}

public enum EPUBParserError: LocalizedError, Sendable, Equatable {
    case fileDoesNotExist(URL)
    case unreadableArchive(URL)
    case missingContainer
    case invalidContainer
    case missingPackageDocument(String)
    case invalidPackageDocument(String)
    case missingSpine
    case noReadableContent
    case missingArchiveEntry(String)
    case unsafeArchivePath(String)
    case entryTooLarge(path: String, limit: Int)
    case archiveTooLarge(limit: Int)
    case unsupportedTextEncoding(String)
    case encryptedEPUB
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .fileDoesNotExist(let url):
            return "EPUB file does not exist: \(url.path)"
        case .unreadableArchive(let url):
            return "Unable to read EPUB archive: \(url.path)"
        case .missingContainer:
            return "Missing META-INF/container.xml."
        case .invalidContainer:
            return "Invalid EPUB container.xml."
        case .missingPackageDocument(let path):
            return "Missing EPUB package document: \(path)"
        case .invalidPackageDocument(let path):
            return "Invalid EPUB package document: \(path)"
        case .missingSpine:
            return "The EPUB package has no readable spine."
        case .noReadableContent:
            return "No readable XHTML/HTML content was found in the EPUB spine."
        case .missingArchiveEntry(let path):
            return "Missing archive entry: \(path)"
        case .unsafeArchivePath(let path):
            return "Unsafe path inside EPUB archive: \(path)"
        case .entryTooLarge(let path, let limit):
            return "EPUB entry exceeds the configured size limit (\(limit) bytes): \(path)"
        case .archiveTooLarge(let limit):
            return "EPUB archive exceeds the configured total extraction limit (\(limit) bytes)."
        case .unsupportedTextEncoding(let path):
            return "Unsupported text encoding for EPUB entry: \(path)"
        case .encryptedEPUB:
            return "This EPUB appears to be encrypted or DRM-protected."
        case .cancelled:
            return "EPUB parsing was cancelled."
        }
    }
}
