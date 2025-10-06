// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftLLDP",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "SwiftLLDP",
            targets: ["SwiftLLDP"]
        ),
        .executable(
            name: "swift-lldp",
            targets: ["SwiftLLDPCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0")
    ],
    targets: [
        .systemLibrary(
            name: "CLibpcap",
            pkgConfig: "libpcap"
        ),
        .target(
            name: "SwiftLLDP",
            dependencies: [
                "CLibpcap"
            ]
        ),
        .executableTarget(
            name: "SwiftLLDPCLI",
            dependencies: [
                "SwiftLLDP",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "SwiftLLDPTests",
            dependencies: ["SwiftLLDP"]
        ),
    ]
)
