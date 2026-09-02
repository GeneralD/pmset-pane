// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PMSetPane",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "PMSetPane", type: .dynamic, targets: ["PMSetPane"]),
        .executable(name: "PowerManagementMonitor", targets: ["PowerManagementMonitor"]),
    ],
    targets: [
        .target(name: "PowerManagementCore"),
        .target(name: "PMSetPane", dependencies: ["PowerManagementCore"]),
        .executableTarget(name: "PowerManagementMonitor", dependencies: ["PowerManagementCore"]),
        .testTarget(name: "PMSetPaneTests", dependencies: ["PMSetPane", "PowerManagementCore"]),
    ],
    swiftLanguageModes: [.v5]
)
