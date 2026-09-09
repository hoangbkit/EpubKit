import Foundation
@preconcurrency import ZIPFoundation

final class ArchiveDataReader {
    private let archive: Archive
    private let options: EPUBParsingOptions
    private var totalExtractedBytes: Int = 0

    init(fileURL: URL, options: EPUBParsingOptions) throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw EPUBParserError.fileDoesNotExist(fileURL)
        }
        guard let archive = Archive(url: fileURL, accessMode: .read) else {
            throw EPUBParserError.unreadableArchive(fileURL)
        }
        self.archive = archive
        self.options = options
    }

    func contains(_ path: String) -> Bool {
        let trimmed = safeLookupPath(path)
        if archive[trimmed] != nil {
            return true
        }
        // Mirror readData's fallback so both lookups agree: an OPF referenced
        // as "content 1.opf" may be stored in the zip percent-encoded.
        return archive[trimmed.removingPercentEncoding ?? trimmed] != nil
    }

    func readString(_ path: String) throws -> String {
        let data = try readData(path)

        // NUL bytes are illegal in XML and never occur in valid UTF-8 text
        // documents, but they do occur in BOM-less UTF-16 — which also
        // "decodes" as UTF-8. Rejecting NUL-containing UTF-8 sends such data
        // to the UTF-16 detection below instead of decoding it as mojibake.
        if let string = String(data: data, encoding: .utf8), !string.contains("\u{0}") {
            return string
        }

        if hasUTF16ByteOrderMark(data),
           let string = String(data: data, encoding: .utf16) {
            return string
        }

        if let encoding = inferredUTF16Encoding(data),
           let string = String(data: data, encoding: encoding) {
            return string
        }

        if let string = String(data: data, encoding: .isoLatin1) {
            return string
        }

        throw EPUBParserError.unsupportedTextEncoding(path)
    }

    func readData(_ path: String) throws -> Data {
        try validateSafeArchivePath(path)

        let lookupPath = safeLookupPath(path)
        guard let entry = archive[lookupPath] ?? archive[path.removingPercentEncoding ?? path] else {
            throw EPUBParserError.missingArchiveEntry(path)
        }

        let expectedSize = Int(entry.uncompressedSize)
        if expectedSize > options.maxEntrySizeBytes {
            throw EPUBParserError.entryTooLarge(path: path, limit: options.maxEntrySizeBytes)
        }

        var data = Data()
        var didOverflowEntryLimit = false
        data.reserveCapacity(max(0, expectedSize))

        _ = try archive.extract(entry) { chunk in
            guard !didOverflowEntryLimit else { return }

            if data.count + chunk.count > self.options.maxEntrySizeBytes {
                didOverflowEntryLimit = true
                return
            }

            data.append(chunk)
        }

        if didOverflowEntryLimit || data.count > options.maxEntrySizeBytes {
            throw EPUBParserError.entryTooLarge(path: path, limit: options.maxEntrySizeBytes)
        }

        totalExtractedBytes += data.count
        if totalExtractedBytes > options.maxTotalExtractedBytes {
            throw EPUBParserError.archiveTooLarge(limit: options.maxTotalExtractedBytes)
        }

        return data
    }

    private func hasUTF16ByteOrderMark(_ data: Data) -> Bool {
        guard data.count >= 2 else { return false }
        return (data[data.startIndex] == 0xFF && data[data.index(after: data.startIndex)] == 0xFE)
            || (data[data.startIndex] == 0xFE && data[data.index(after: data.startIndex)] == 0xFF)
    }

    private func inferredUTF16Encoding(_ data: Data) -> String.Encoding? {
        let sample = Array(data.prefix(64))
        guard sample.count >= 4 else { return nil }

        var evenNulls = 0
        var oddNulls = 0

        for (index, byte) in sample.enumerated() where byte == 0 {
            if index.isMultiple(of: 2) {
                evenNulls += 1
            } else {
                oddNulls += 1
            }
        }

        let pairs = sample.count / 2
        let threshold = max(2, pairs / 3)

        if oddNulls >= threshold, evenNulls <= 1 {
            return .utf16LittleEndian
        }
        if evenNulls >= threshold, oddNulls <= 1 {
            return .utf16BigEndian
        }

        return nil
    }

    private func safeLookupPath(_ path: String) -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func validateSafeArchivePath(_ path: String) throws {
        if path.hasPrefix("/") || path.contains("\\") {
            throw EPUBParserError.unsafeArchivePath(path)
        }

        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        if components.contains("..") {
            throw EPUBParserError.unsafeArchivePath(path)
        }
    }
}
