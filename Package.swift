// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AeroSpacePackage",
    // Runtime support for parameterized protocol types is only available in macOS 13.0.0 or newer
    // And it specifies deploymentTarget for CLI
    platforms: [.macOS(.v13)],
    // Products define the executables and libraries a package produces, making them visible to other packages.
    products: [
        .executable(name: "aerospace", targets: ["Cli"]),
        // Don't use this build for release, use xcode instead
        .executable(name: "AeroSpaceApp", targets: ["AeroSpaceApp"]),
        // We only need to expose this as a product for xcode
        .library(name: "AppBundle", targets: ["AppBundle"]),
    ],
    dependencies: [
        .package(url: "https://github.com/InerziaSoft/ISSoundAdditions", exact: "2.0.1"),
        .package(url: "https://github.com/Kitura/BlueSocket", exact: "2.0.4"),
        .package(url: "https://github.com/soffes/HotKey", exact: "0.1.3"),
        .package(url: "https://github.com/LebJe/TOMLKit", exact: "0.5.5"),
        .package(url: "https://github.com/apple/swift-collections", exact: "1.1.0"),
        .package(path: "./ShellParserGenerated"),
    ],
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    targets: [
        // Exposes the prviate _AXUIElementGetWindow function to swift
        .target(
            name: "PrivateApi",
            path: "Sources/PrivateApi",
            publicHeadersPath: "include"
        ),
        .target(
            name: "Common",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
        .target(
            name: "AppBundle",
            dependencies: [
                .target(name: "PrivateApi"),
                .target(name: "Common"),
                .product(name: "ShellParserGenerated", package: "ShellParserGenerated"),
                .product(name: "Socket", package: "BlueSocket"),
                .product(name: "HotKey", package: "HotKey"),
                .product(name: "ISSoundAdditions", package: "ISSoundAdditions"),
                .product(name: "TOMLKit", package: "TOMLKit"),
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
        .executableTarget(
            name: "AeroSpaceApp",
            dependencies: [
                .target(name: "AppBundle"),
            ]
        ),
        .executableTarget(
            name: "Cli",
            dependencies: [
                .target(name: "Common"),
                .product(name: "Socket", package: "BlueSocket"),
            ]
        ),
        .testTarget(
            name: "AppBundleTests",
            dependencies: [
                .target(name: "AppBundle"),
            ]
        ),
    ]
)
