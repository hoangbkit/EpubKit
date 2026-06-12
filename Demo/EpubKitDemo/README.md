# EpubKitDemo

A small macOS SwiftUI demo app for `EpubKit`.

## Run

1. Open `Demo/EpubKitDemo/EpubKitDemo.xcodeproj` in Xcode.
2. Select the `EpubKitDemo` scheme.
3. Build and run.
4. Open or drag an `.epub` file.

The project uses the package at `../..` as a local Swift Package dependency.

## What it demonstrates

- `NSOpenPanel` file import
- sandbox-safe security-scoped access
- async `EPUBParser().parseAsync(fileURL:)`
- progress updates
- metadata display
- chapter list
- extracted readable text preview
- diagnostics display
- copy selected chapter / copy all text
