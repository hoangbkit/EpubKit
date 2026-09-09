import Foundation
import XCTest
import ZIPFoundation
@testable import EpubKit

/// Shared builders for constructing EPUB archives with exactly the layout a
/// test needs. Entries are written in sorted order so archives are deterministic.
extension XCTestCase {
    func makeEPUB(
        opf: String,
        opfPath: String = "OEBPS/content.opf",
        entries: [String: Data] = [:],
        encryptionXML: String? = nil
    ) throws -> URL {
        var allEntries: [String: Data] = [
            "mimetype": Data("application/epub+zip".utf8),
            "META-INF/container.xml": Data(containerXML(packagePath: opfPath).utf8),
            opfPath: Data(opf.utf8)
        ]
        entries.forEach { allEntries[$0.key] = $0.value }
        if let encryptionXML {
            allEntries["META-INF/encryption.xml"] = Data(encryptionXML.utf8)
        }
        return try makeArchive(entries: allEntries)
    }

    func makeArchive(entries: [String: Data]) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("epub")
        let archive = try Archive(url: url, accessMode: .create)

        for path in entries.keys.sorted() {
            let data = try XCTUnwrap(entries[path])
            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: Int64(data.count),
                provider: { position, size in
                    let start = Int(position)
                    return data.subdata(in: start..<(start + size))
                }
            )
        }

        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    func containerXML(packagePath: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
          <rootfiles><rootfile full-path="\(packagePath)" media-type="application/oebps-package+xml"/></rootfiles>
        </container>
        """
    }

    func minimalOPF(manifest: String, spine: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>Test Book</dc:title></metadata>
          <manifest>\(manifest)</manifest>
          <spine>\(spine)</spine>
        </package>
        """
    }

    func chapterHTML(title: String?, body: String) -> String {
        let titleElement = title.map { "<title>\($0)</title>" } ?? ""
        return "<html><head>\(titleElement)</head><body><p>\(body)</p></body></html>"
    }
}

/// Small indirection so a progress callback can cancel the parsing task that
/// invoked it: the task identity is assigned after the Task starts.
final class CancelTaskHandle: @unchecked Sendable {
    var target: Task<EPUBDocument, Error>?

    func cancel() {
        target?.cancel()
    }
}
