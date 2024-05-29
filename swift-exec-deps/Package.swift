// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftExecDeps",
    platforms: [.macOS(.v13)],
    products: [],
    dependencies: [
        .package(url: "https://github.com/yonaskolb/XcodeGen.git", exact: "2.42.0"),
        .package(url: "https://github.com/realm/SwiftLint", exact: "0.55.1"),
    ],
    targets: []
)
