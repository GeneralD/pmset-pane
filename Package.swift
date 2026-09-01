// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PMSetPane",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PMSetPane", type: .dynamic, targets: ["PMSetPane"]),
    ],
    targets: [
        .target(name: "PMSetPane"),
        .testTarget(name: "PMSetPaneTests", dependencies: ["PMSetPane"]),
    ],
    swiftLanguageModes: [.v5]
)
