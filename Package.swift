// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AeroSpacePackage",
    platforms: [.macOS(.v13)], /* Runtime support for parameterized protocol types is only available in macOS 13.0.0 or newer
                                  And it specifies deploymentTarget for CLI */
    // Products define the executables and libraries a package produces, making them visible to other packages.
    products: [
        .library(name: "AppBundle", targets: ["AppBundle"]),
        .executable(name: "aerospace", targets: ["Cli"])
    ],
    dependencies: [
        .package(url: "https://github.com/Kitura/BlueSocket", exact: "2.0.4"),
        .package(url: "https://github.com/soffes/HotKey", exact: "0.1.3"),
        .package(url: "https://github.com/LebJe/TOMLKit", exact: "0.5.5"),
        .package(url: "https://github.com/Quick/Nimble", exact: "12.0.0"),
        .package(url: "https://github.com/apple/swift-collections", exact: "1.1.0"),
    ],
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    targets: [
        .target(
            name: "Common",
            dependencies: [
                .product(name: "Collections", package: "swift-collections"),
            ]
        ),
        .target(
            name: "AppBundle",
            dependencies: [
                .target(name: "Common"),
                .product(name: "Socket", package: "BlueSocket"),
                .product(name: "HotKey", package: "HotKey"),
                .product(name: "TOMLKit", package: "TOMLKit"),
                .product(name: "Collections", package: "swift-collections"),
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
                .product(name: "Nimble", package: "Nimble"),
            ]
        ),
    ]
)
