# EpubKit

A focused Swift Package for extracting clean, TTS-ready readable text from `.epub` files on macOS and iOS.

This is not an EPUB renderer. It implements the extraction path most apps need when they want chapter text, metadata, cover artwork, a structured table of contents, and diagnostics:

```text
EPUB ZIP
→ META-INF/container.xml
→ OPF package document
→ manifest + spine reading order
→ EPUB 3 nav / EPUB 2 NCX
→ cover resource
→ XHTML/HTML chapters
→ normalized readable text
```

## Features

- In-memory ZIP reading with `ZIPFoundation`
- XHTML/HTML cleanup with `SwiftSoup`
- EPUB spine-order extraction
- Metadata extraction: title, creator, language, identifiers, publisher, modified date
- EPUB 3 `nav.xhtml` and EPUB 2 `.ncx` table-of-contents support
- Hierarchical public table-of-contents model
- EPUB 3 `cover-image` and EPUB 2 legacy cover metadata support
- Fixed-layout warning
- Encryption/DRM hinting
- Max entry and total extraction limits to reduce zip-bomb risk
- Sync and async parsing APIs
- Progress callback and task cancellation
- Production-oriented generated EPUB test coverage
- macOS SwiftUI demo app in `Demo/EpubKitDemo`

## Install

Add this package to your app, or copy the `Sources/EpubKit` folder into your own package.

```swift
.package(url: "https://github.com/your-org/EpubKit.git", from: "1.0.0")
```

Then add the product:

```swift
.product(name: "EpubKit", package: "EpubKit")
```

## Usage

```swift
import EpubKit

let url = URL(fileURLWithPath: "/path/to/book.epub")
let document = try EPUBParser().parse(fileURL: url)

print(document.metadata.title ?? "Untitled")
print(document.chapters.count)

if let cover = document.cover {
    print(cover.mediaType)
    print(cover.data.count)
}

for item in document.tableOfContents {
    print(item.title)
}

for chapter in document.chapters {
    print(chapter.title ?? chapter.href)
    print(chapter.text.prefix(500))
}
```

`EPUBCover` contains raw `Data`, media type, and resolved archive path. It intentionally does not expose `NSImage` or `UIImage`, keeping EpubKit independent from UI frameworks.

`EPUBTOCItem` preserves nested EPUB navigation structure through its `children` array. Chapter extraction still follows OPF spine order; the TOC is navigation metadata rather than a replacement for the spine.

## Async usage in SwiftUI/macOS

```swift
Task.detached(priority: .userInitiated) {
    do {
        let document = try await EPUBParser().parseAsync(fileURL: epubURL) { progress in
            print(progress.fractionCompleted)
        }

        await MainActor.run {
            self.sections = document.readableSections
        }
    } catch {
        await MainActor.run {
            self.errorMessage = error.localizedDescription
        }
    }
}
```

## macOS demo app

Open:

```text
Demo/EpubKitDemo/EpubKitDemo.xcodeproj
```

The demo app shows:

- `NSOpenPanel` EPUB import
- sandbox-safe security-scoped file access
- async parsing with progress
- metadata and diagnostics
- spine-ordered chapter list
- extracted text preview
- copy selected chapter / copy all text

The demo Xcode project references the root package as a local Swift Package dependency at `../..`.

## TTS / audiobook integration

Use `document.readableSections` as your initial audiobook sections, then chunk per section:

```swift
let document = try await EPUBParser().parseAsync(fileURL: epubURL)
let sections = document.readableSections

for section in sections {
    print(section.title ?? section.sourcePath)
    print(section.text.count)
}
```

Keep chapter boundaries first. Do not join the whole book into one huge string before chunking.

For an audiobook-management UI, EpubKit should remain the EPUB ingestion layer. The host app should own persistence, synthesis jobs, voices/models, generated audio, playback, and export.

## Notes

- DRM-protected EPUBs cannot be reliably parsed. This package detects common encryption hints and will throw `EPUBParserError.encryptedEPUB` when no readable content can be extracted.
- Fixed-layout EPUBs may be image-heavy or out of reading order. The package returns a warning diagnostic but still extracts available text.
- Missing or unreadable cover resources are reported as diagnostics and do not prevent readable chapters from being returned.
- For production TTS, parse once into sections, persist the section model, and chunk each section independently.
