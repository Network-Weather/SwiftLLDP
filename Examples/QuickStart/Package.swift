// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "QuickStart",
  platforms: [
    .macOS(.v13)
  ],
  dependencies: [
    .package(path: "../../")
  ],
  targets: [
    .executableTarget(
      name: "QuickStart",
      dependencies: [
        .product(name: "SwiftLLDP", package: "SwiftLLDP")
      ]
    )
  ]
)
