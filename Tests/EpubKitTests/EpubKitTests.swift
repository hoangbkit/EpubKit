import XCTest
@testable import EpubKit

final class EpubKitTests: XCTestCase {
    func testParsesMinimalEPUBInSpineOrder() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "minimal", withExtension: "epub", subdirectory: "Fixtures"))

        let document = try EPUBParser().parse(fileURL: url)

        XCTAssertEqual(document.metadata.title, "EpubKit Test Book")
        XCTAssertEqual(document.metadata.creators, ["Hoang Nguyen"])
        XCTAssertEqual(document.metadata.language, "en")
        XCTAssertEqual(document.chapters.count, 2)
        XCTAssertEqual(document.chapters[0].title, "Chapter One")
        XCTAssertEqual(document.chapters[1].title, "Chapter Two")
        XCTAssertTrue(document.chapters[0].text.contains("Hello from chapter one."))
        XCTAssertTrue(document.chapters[0].text.contains("This is a second paragraph."))
        XCTAssertFalse(document.chapters[0].text.contains("Navigation should be removed."))
        XCTAssertFalse(document.chapters[1].text.contains("This should not appear."))
    }

    func testCompactWhitespaceMode() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "minimal", withExtension: "epub", subdirectory: "Fixtures"))

        let options = EPUBParsingOptions(whitespaceMode: .compact)
        let document = try EPUBParser().parse(fileURL: url, options: options)

        XCTAssertFalse(document.chapters[0].text.contains("\n\n"))
        XCTAssertTrue(document.chapters[0].text.contains("Hello from chapter one."))
    }

    func testProgressCallbackCompletes() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "minimal", withExtension: "epub", subdirectory: "Fixtures"))
        var progressValues: [Double] = []

        _ = try EPUBParser().parse(fileURL: url) { progress in
            progressValues.append(progress.fractionCompleted)
        }

        XCTAssertEqual(progressValues.last, 1.0)
    }
}
