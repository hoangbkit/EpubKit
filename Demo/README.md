# EpubKitDemo

A small shared SwiftUI demo for `EpubKit` with separate macOS and iOS application targets.

The demo is intentionally kept directly under `Demo/` so tools such as `mycli` can discover and run the XcodeGen project without traversing a deeply nested directory structure.

## Targets

- `EpubKitDemo` — macOS 15+, bundle identifier `com.hoangbkit.epubkit.demo`
- `EpubKitDemo-iOS` — iOS 16+, bundle identifier `com.hoangbkit.epubkit.demo.ios`

The package itself supports iOS 15+. The iOS Demo uses iOS 16+ because the shared interface uses `NavigationSplitView`.

## Generate and run

```bash
cd Demo
xcodegen generate --spec project.yml
open EpubKitDemo.xcodeproj
```

Choose `EpubKitDemo` for macOS or `EpubKitDemo-iOS` for iOS. The generated `EpubKitDemo.xcodeproj` is ignored by Git and should not be committed.

The project uses the package at `..` as a local Swift Package dependency.

## What it demonstrates

- macOS `NSOpenPanel` import and drag-and-drop
- iOS `fileImporter`
- sandbox-safe security-scoped access
- async `EPUBParser().parseAsync(fileURL:)`
- progress updates
- metadata display
- chapter list
- extracted readable text preview
- diagnostics display
- copy selected chapter / copy all text

## Demo Release

The manual Demo Release workflow supports:

- platform: `macOS`, `iOS`, or `both`
- configuration: `Debug`, `Release`, or `both`

All selected artifacts are published in one `mycli-build-*` prerelease. macOS uses an unsigned universal `.app.zip`; iOS uses an unsigned `.xcarchive.zip` for local mycli signing/export.
