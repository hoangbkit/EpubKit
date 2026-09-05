# EpubKitDemo

A small macOS SwiftUI demo app for `EpubKit`.

The Xcode project is generated with [XcodeGen](https://github.com/yonaskolb/XcodeGen) from `project.yml`. The generated `EpubKitDemo.xcodeproj` is intentionally not committed.

## Requirements

- macOS 13+
- Xcode 16+
- XcodeGen 2.38+

Install XcodeGen with Homebrew if needed:

```sh
brew install xcodegen
```

## Generate and run

From this directory:

```sh
xcodegen generate
open EpubKitDemo.xcodeproj
```

Then select the `EpubKitDemo` scheme, build and run, and open or drag an `.epub` file.

The generated project uses the package at `../..` as a local Swift Package dependency.

## Command-line build

```sh
xcodegen generate
xcodebuild \
  -project EpubKitDemo.xcodeproj \
  -scheme EpubKitDemo \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

GitHub Actions runs the same generation/build path on an Apple Silicon macOS runner after the Swift package tests.

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
