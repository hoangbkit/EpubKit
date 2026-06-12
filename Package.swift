// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "EpubKit",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "EpubKit",
            targets: ["EpubKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.20"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.13.5")
    ],
    targets: [
        .target(
            name: "EpubKit",
            dependencies: [
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "SwiftSoup", package: "SwiftSoup")
            ]
        ),
        .testTarget(
            name: "EpubKitTests",
            dependencies: ["EpubKit"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
