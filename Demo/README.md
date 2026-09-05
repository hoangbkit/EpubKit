# EpubKitDemo

A small macOS SwiftUI demo app for `EpubKit`.

The demo is intentionally kept directly under `Demo/` so tools such as `mycli` can discover and run the XcodeGen project without traversing a deeply nested directory structure.

## Generate and run

```bash
cd Demo
xcodegen generate
open EpubKitDemo.xcodeproj
```

Select the `EpubKitDemo` scheme, then build and run. The generated `EpubKitDemo.xcodeproj` is ignored by Git and should not be committed.

The project uses the package at `..` as a local Swift Package dependency and uses bundle identifier `com.hoangbkit.epubkit.demo`.

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
