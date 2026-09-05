import AppKit
import EpubKit
import Foundation
import UniformTypeIdentifiers

@MainActor
final class DemoViewModel: ObservableObject {
    @Published var sourceURL: URL?
    @Published var document: EPUBDocument?
    @Published var selectedChapterID: String?
    @Published var isParsing = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?

    var selectedChapter: EPUBChapter? {
        guard let selectedChapterID else { return document?.chapters.first }
        return document?.chapters.first { $0.id == selectedChapterID }
    }

    var bookTitle: String {
        document?.metadata.title ?? sourceURL?.deletingPathExtension().lastPathComponent ?? "No EPUB Loaded"
    }

    func openEPUBPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open EPUB"
        panel.message = "Choose an .epub file to extract readable chapter text."
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.epub]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            await parse(url: url)
        }
    }

    func parse(url: URL) async {
        isParsing = true
        progress = 0
        errorMessage = nil
        sourceURL = url
        document = nil
        selectedChapterID = nil

        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let parser = EPUBParser()
            let parsedDocument = try await parser.parseAsync(fileURL: url) { [weak self] progress in
                Task { @MainActor [weak self] in
                    self?.progress = progress.fractionCompleted
                }
            }

            document = parsedDocument
            selectedChapterID = parsedDocument.chapters.first?.id
            progress = 1
        } catch {
            errorMessage = error.localizedDescription
        }

        isParsing = false
    }

    func copySelectedChapterText() {
        guard let text = selectedChapter?.text, !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func copyAllText() {
        guard let text = document?.plainText, !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

extension UTType {
    static let epub = UTType(filenameExtension: "epub") ?? UTType.data
}
