import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var model = DemoViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 440)
        } detail: {
            detail
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.openEPUBPanel()
                } label: {
                    Label("Open EPUB", systemImage: "book")
                }

                Button {
                    model.copyAllText()
                } label: {
                    Label("Copy All Text", systemImage: "doc.on.doc")
                }
                .disabled(model.document == nil)
            }
        }
        .overlay(dropOverlay)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted, perform: handleDrop(providers:))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(16)

            Divider()

            if let document = model.document {
                List(selection: $model.selectedChapterID) {
                    Section("Chapters") {
                        ForEach(document.chapters) { chapter in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.title ?? "Chapter \(chapter.order + 1)")
                                    .font(.headline)
                                    .lineLimit(2)

                                Text("\(chapter.characterCount.formatted()) characters")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .tag(chapter.id)
                        }
                    }

                    if !document.diagnostics.isEmpty {
                        Section("Diagnostics") {
                            ForEach(Array(document.diagnostics.enumerated()), id: \.offset) { _, diagnostic in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(diagnostic.severity.rawValue.capitalized)
                                        .font(.caption.bold())
                                    Text(diagnostic.message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(.vertical, 3)
                            }
                        }
                    }
                }
            } else {
                emptySidebar
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.bookTitle)
                .font(.title2.bold())
                .lineLimit(2)

            if let document = model.document {
                let creators = document.metadata.creators.joined(separator: ", ")
                if !creators.isEmpty {
                    Text(creators)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 12) {
                    Label("\(document.chapters.count) chapters", systemImage: "list.bullet.rectangle")
                    Label("\(document.plainText.count.formatted()) chars", systemImage: "textformat.size")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if model.isParsing {
                ProgressView(value: model.progress)
                    .controlSize(.small)
            }

            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var emptySidebar: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)

            Text("Open or drag an EPUB file")
                .font(.headline)

            Text("The demo extracts spine-ordered XHTML text, chapter titles, metadata, and diagnostics using EpubKit.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Open EPUB") {
                model.openEPUBPanel()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var detail: some View {
        Group {
            if let chapter = model.selectedChapter {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chapter.title ?? "Chapter \(chapter.order + 1)")
                                .font(.title.bold())
                                .lineLimit(2)

                            Text(chapter.href)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            model.copySelectedChapterText()
                        } label: {
                            Label("Copy Chapter", systemImage: "doc.on.doc")
                        }
                    }
                    .padding(20)

                    Divider()

                    ScrollView {
                        Text(chapter.text)
                            .font(.body)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Chapter Selected")
                        .font(.title2.bold())
                    Text("Open an EPUB file to inspect extracted readable text.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private var dropOverlay: some View {
        if isDropTargeted {
            RoundedRectangle(cornerRadius: 18)
                .fill(.background.opacity(0.82))
                .overlay {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.doc")
                            .font(.system(size: 48))
                        Text("Drop EPUB to parse")
                            .font(.title2.bold())
                    }
                }
                .padding(24)
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data,
                  let url = URL(dataRepresentation: data, relativeTo: nil),
                  url.pathExtension.lowercased() == "epub" else {
                return
            }

            Task { @MainActor in
                await model.parse(url: url)
            }
        }

        return true
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
