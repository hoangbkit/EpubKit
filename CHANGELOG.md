# Changelog

All notable changes to EpubKit are documented in this file.

## [1.0.0] - 2026-09-05

Initial production release.

### EPUB parsing

- Parse EPUB archives directly from a file URL with `ZIPFoundation` without unpacking the whole book to a temporary directory.
- Read `META-INF/container.xml` and resolve the OPF package document.
- Parse the OPF manifest and spine and return readable chapters in spine order.
- Support XHTML/HTML spine resources and skip non-readable spine resources.
- Resolve relative resource paths, fragments, and percent-encoded paths.
- Continue past missing or unreadable individual chapters when other readable content is available, reporting diagnostics instead of failing the whole book.

### Text extraction

- Extract readable text from XHTML/HTML with `SwiftSoup`.
- Preserve paragraph boundaries by default, with an optional compact-whitespace mode.
- Remove common non-content elements such as scripts, styles, navigation, headers, footers, page-number markers, media, SVG, and other configurable selectors.
- Allow callers to provide custom CSS selectors to remove during extraction.
- Recover useful text from malformed HTML where SwiftSoup can repair the document.
- Drop empty chapters by default, with an option to retain them.
- Derive chapter titles from the EPUB table of contents first, then document headings/title, then the spine identifier.
- Expose `EPUBDocument.plainText` and spine-aligned `readableSections` for downstream processing such as TTS.

### Metadata

- Extract title.
- Extract one or more creators.
- Extract language.
- Extract identifiers.
- Extract publisher.
- Extract `dcterms:modified`.
- Extract `rendition:layout` and warn for fixed-layout (`pre-paginated`) books.

### Table of contents

- Support EPUB 3 navigation documents (`nav.xhtml`).
- Support EPUB 2 NCX tables of contents.
- Preserve nested navigation as public hierarchical `EPUBTOCItem` values.
- Resolve TOC links to archive-relative paths.
- Use TOC labels to improve spine chapter titles.
- Fall back from an unreadable/missing EPUB 3 navigation document to NCX when available.
- Allow TOC parsing to be disabled.

### Cover artwork

- Support EPUB 3 manifest items with `properties="cover-image"`.
- Support EPUB 2 legacy `<meta name="cover" content="...">` metadata.
- Expose cover bytes as platform-neutral `Data` with media type and resolved archive path through `EPUBCover`.
- Treat missing, unreadable, or non-image cover resources as non-fatal diagnostics.

### Safety and resilience

- Reject unsafe archive paths such as traversal paths.
- Enforce a configurable maximum size for each extracted archive entry.
- Enforce a configurable maximum total number of extracted bytes.
- Detect `META-INF/encryption.xml` and report an encryption/DRM warning while still attempting readable content extraction.
- Throw `encryptedEPUB` when encryption metadata is present and no readable content can be extracted.
- Distinguish missing/invalid container, missing/invalid package document, missing spine, unreadable archive, missing archive entries, oversized entries, oversized archives, no readable content, and cancellation through `EPUBParserError`.
- Decode UTF-8, UTF-16 (including endian variants), and ISO Latin-1 text without falsely treating Latin-1 data as UTF-16.
- Return non-fatal parser issues through structured `EPUBDiagnostic` values.

### Concurrency and progress

- Provide synchronous `parse` and asynchronous `parseAsync` APIs.
- Provide spine-based progress callbacks through `EPUBParsingProgress`.
- Propagate task cancellation and expose it as `EPUBParserError.cancelled`.

### Public models

- `EPUBDocument`
- `EPUBMetadata`
- `EPUBChapter`
- `EPUBCover`
- `EPUBTOCItem`
- `EPUBReadableSection`
- `EPUBDiagnostic`
- `EPUBParsingOptions`
- `EPUBParsingProgress`
- `EPUBParserError`

### Platforms and tooling

- Support macOS 13 and later.
- Support iOS 16 and later.
- Include a macOS SwiftUI demo app showing EPUB import, security-scoped file access, async parsing, progress, metadata, diagnostics, chapter browsing, text preview, and copying extracted text.
- Include production-oriented generated EPUB fixtures and regression coverage for EPUB 2/3 navigation, covers, malformed input, archive limits, path safety, encodings, metadata, parser options, async parsing, and cancellation.
- Run Swift package tests in GitHub Actions for pushes to `master` and pull requests targeting `master`.

### Scope

EpubKit is an EPUB ingestion and readable-text extraction package. It intentionally does not provide EPUB rendering, bookshelf/library persistence, audiobook job management, TTS synthesis, voice/model selection, audio playback, or export workflows; those responsibilities belong to the host application.
