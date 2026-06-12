import Foundation

public struct EPUBReadableSection: Identifiable, Sendable, Equatable {
    public var id: String
    public var title: String?
    public var text: String
    public var sourcePath: String
    public var order: Int

    public init(id: String, title: String?, text: String, sourcePath: String, order: Int) {
        self.id = id
        self.title = title
        self.text = text
        self.sourcePath = sourcePath
        self.order = order
    }
}

public extension EPUBDocument {
    var readableSections: [EPUBReadableSection] {
        chapters.map {
            EPUBReadableSection(
                id: $0.id,
                title: $0.title,
                text: $0.text,
                sourcePath: $0.href,
                order: $0.order
            )
        }
    }
}
