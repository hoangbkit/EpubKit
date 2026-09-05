# EpubKit

A focused Swift Package for extracting clean, structured, TTS-ready readable content from `.epub` files on macOS and iOS.

EpubKit is **not an EPUB renderer**. It is an ingestion layer for apps that need metadata, cover artwork, a structured table of contents, spine-ordered chapters, readable text, diagnostics, and safe archive handling.

> [!IMPORTANT]
> This repository is public and released under the MIT License, but it is **not maintained as a community-driven open-source project**. It is primarily developed for the author's own apps. Issues, feature requests, and pull requests may not be reviewed or accepted, and no support or maintenance commitment is implied by the repository being public.

```text
EPUB archive
→ META-INF/container.xml
→ OPF package document
→ manifest + spine reading order
→ EPUB 3 nav / EPUB 2 NCX
→ cover resource
→ XHTML/HTML chapters
→ cleaned readable text
```

## Requirements

- Swift 5.9+
- macOS 13+
- iOS 16+

## Features

### Parsing and text extraction

- Reads EPUB archive entries on demand with `ZIPFoundation`
- Parses `container.xml`, OPF manifest, metadata, and spine
- Extracts readable XHTML/HTML with `SwiftSoup`
- Preserves OPF spine reading order
- Resolves relative, percent-encoded, and fragment-containing paths
- Recovers useful text from malformed HTML where possible
- Preserves paragraph boundaries by default or supports compact whitespace
- Drops empty chapters by default, with an option to retain them
- Supports configurable CSS selectors for removing non-content elements

### Metadata and navigation

- Metadata: title, creators, language, identifiers, publisher, modified date, rendition layout
- EPUB 3 `nav.xhtml` support
- EPUB 2 NCX support
- Hierarchical public `EPUBTOCItem` model
- TOC labels used as preferred chapter titles
- NCX fallback when an EPUB 3 navigation resource is unavailable or unreadable

### Cover artwork

- EPUB 3 `properties="cover-image"`
- EPUB 2 `<meta name="cover" content="...">`
- Platform-neutral `EPUBCover` containing raw `Data`, media type, and resolved archive path
- Missing/unreadable covers are non-fatal and reported through diagnostics

### Safety and diagnostics

- Rejects unsafe traversal-style archive paths
- Configurable maximum size per archive entry
- Configurable maximum total extracted bytes
- Encryption/DRM hint detection through `META-INF/encryption.xml`
- Fixed-layout EPUB warning
- Structured non-fatal `EPUBDiagnostic` values
- Typed fatal failures through `EPUBParserError`
- UTF-8, UTF-16, and ISO Latin-1 text decoding

### Concurrency

- Synchronous parsing
- Asynchronous parsing
- Spine-based progress callbacks
- Task cancellation mapped to `EPUBParserError.cancelled`

## Installation

Add EpubKit through Swift Package Manager:

```swift
.package(
    url: "https://github.com/hoangbkit/EpubKit.git",
    from: "1.0.0"
)
```

Then add the library product to your target:

```swift
.product(name: "EpubKit", package: "EpubKit")
```

## Basic usage

```swift
import EpubKit

let url = URL(fileURLWithPath: "/path/to/book.epub")
let document = try EPUBParser().parse(fileURL: url)

print(document.metadata.title ?? "Untitled")
print(document.chapters.count)

if let cover = document.cover {
    print(cover.mediaType)
    print(cover.data.count)
    print(cover.href)
}

for item in document.tableOfContents {
    print(item.title)
}

for chapter in document.chapters {
    print(chapter.title ?? chapter.href)
    print(chapter.text.prefix(500))
}
```

`EPUBCover` intentionally exposes raw data rather than `NSImage` or `UIImage`, keeping the package independent of AppKit and UIKit.

`EPUBTOCItem` preserves nested navigation through its `children` array. Chapter extraction still follows OPF spine order; the TOC is navigation metadata, not the source of reading order.

## Async parsing and progress

```swift
import EpubKit

Task {
    do {
        let document = try await EPUBParser().parseAsync(
            fileURL: epubURL,
            priority: .userInitiated
        ) { progress in
            print(progress.fractionCompleted)
            print(progress.currentPath ?? "done")
        }

        await MainActor.run {
            self.sections = document.readableSections
        }
    } catch EPUBParserError.cancelled {
        // Parsing task was cancelled.
    } catch {
        await MainActor.run {
            self.errorMessage = error.localizedDescription
        }
    }
}
```

Cancelling the surrounding task propagates into parsing:

```swift
let task = Task {
    try await EPUBParser().parseAsync(fileURL: epubURL)
}

task.cancel()
```

## Parsing options

```swift
let options = EPUBParsingOptions(
    whitespaceMode: .preserveParagraphs,
    dropEmptyChapters: true,
    parseTableOfContentsTitles: true,
    detectEncryptedEPUB: true,
    maxEntrySizeBytes: 30 * 1024 * 1024,
    maxTotalExtractedBytes: 300 * 1024 * 1024,
    removeCSSSelectors: EPUBParsingOptions.defaultRemoveCSSSelectors + [
        ".advertisement",
        ".promo"
    ]
)

let document = try EPUBParser().parse(
    fileURL: epubURL,
    options: options
)
```

The defaults are designed for normal prose EPUB ingestion and TTS-oriented extraction.

## Main public models

### `EPUBDocument`

The parsed book:

```swift
public struct EPUBDocument {
    public var metadata: EPUBMetadata
    public var chapters: [EPUBChapter]
    public var cover: EPUBCover?
    public var tableOfContents: [EPUBTOCItem]
    public var diagnostics: [EPUBDiagnostic]
}
```

It also exposes:

```swift
document.plainText
document.readableSections
```

### `EPUBChapter`

Each readable spine item includes its identifier, reading order, optional title, resolved archive path, media type, OPF properties, and cleaned text.

### `EPUBTOCItem`

Hierarchical EPUB navigation:

```swift
func printTOC(_ items: [EPUBTOCItem], depth: Int = 0) {
    for item in items {
        print(String(repeating: "  ", count: depth) + item.title)
        printTOC(item.children, depth: depth + 1)
    }
}

printTOC(document.tableOfContents)
```

### `EPUBReadableSection`

A lightweight spine-aligned model useful for downstream TTS or other text-processing pipelines:

```swift
for section in document.readableSections {
    print(section.order)
    print(section.title ?? section.sourcePath)
    print(section.text.count)
}
```

## Error handling

Fatal parsing failures are surfaced as `EPUBParserError`, including:

- file does not exist
- unreadable archive
- missing or invalid `container.xml`
- missing or invalid OPF package document
- missing spine
- no readable content
- missing archive entry
- unsafe archive path
- entry too large
- total extraction limit exceeded
- encrypted EPUB with no readable content
- cancellation

Recoverable conditions are generally placed in `document.diagnostics` instead. For example, an individual missing chapter or cover resource does not necessarily make the entire book unreadable.

```swift
for diagnostic in document.diagnostics {
    print(diagnostic.severity)
    print(diagnostic.message)
    print(diagnostic.path ?? "")
}
```

## EPUB compatibility notes

- DRM-protected EPUBs cannot be reliably extracted. EpubKit warns when encryption metadata exists and throws `encryptedEPUB` when no readable content can be recovered.
- Some EPUBs use `encryption.xml` only for obfuscated font resources; its presence alone does not cause parsing to fail.
- Fixed-layout EPUBs may be image-heavy or have text in an order that does not match their visual presentation. EpubKit warns but still returns readable text when available.
- Cover failures are non-fatal.
- EpubKit is intentionally not a layout/rendering engine and does not attempt to reproduce CSS, pagination, images, typography, or interactive content.

## TTS and audiobook integration

For audiobook-style workflows, use the EPUB spine as the first level of segmentation:

```swift
let document = try await EPUBParser().parseAsync(fileURL: epubURL)

for section in document.readableSections {
    // Chunk section.text according to your TTS model's limits.
}
```

Keep chapter/section boundaries instead of joining the whole book into a single large string before chunking.

EpubKit should remain the ingestion layer. The host application should own:

- file-access bookmarks and library persistence
- TTS chunking policy
- voices and models
- synthesis jobs and progress
- generated audio persistence
- playback
- export
- application UI

## Demo app

A macOS SwiftUI demo is included at:

```text
Demo/EpubKitDemo
```

The demo project is generated with XcodeGen from `Demo/EpubKitDemo/project.yml`; the generated `EpubKitDemo.xcodeproj` is intentionally not committed.

Generate and open it with:

```sh
cd Demo/EpubKitDemo
brew install xcodegen # once, if needed
xcodegen generate
open EpubKitDemo.xcodeproj
```

It demonstrates:

- `NSOpenPanel` EPUB import
- security-scoped file access
- async parsing and progress
- metadata and diagnostics
- spine-ordered chapter browsing
- extracted-text preview
- copying selected chapter text or all extracted text

The generated project references the root repository as a local Swift Package dependency at `../..`.

## Testing

The package includes generated and fixture-based EPUB tests covering core parsing plus production-oriented edge cases such as:

- EPUB 2 and EPUB 3 navigation
- nested TOCs
- legacy and modern cover metadata
- malformed container/package documents
- missing resources
- malformed HTML recovery
- percent-encoded paths
- unsafe archive paths
- entry and total extraction limits
- encryption hints
- fixed-layout metadata
- UTF-16 and Latin-1 decoding
- metadata extraction
- parser options
- async parsing and cancellation

GitHub Actions runs `swift test` for pushes to `master` and pull requests targeting `master`. On the Apple Silicon macOS runner, CI also verifies `arm64`, generates the demo project with XcodeGen, and builds the `EpubKitDemo` scheme with `xcodebuild`.

## Changelog

See [`CHANGELOG.md`](CHANGELOG.md) for release notes. Version `1.0.0` is the first production release.

## License

EpubKit is available under the MIT License. See [`LICENSE`](LICENSE).

The MIT license permits use, modification, and redistribution; the maintenance notice at the top of this README describes project governance/support expectations, not a restriction on those license rights.
