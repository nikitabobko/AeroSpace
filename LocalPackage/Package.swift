// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AeroSpacePackage",
    platforms: [.macOS(.v13)], /* Runtime support for parameterized protocol types is only available in macOS 13.0.0 or newer
                                  And it specifies deploymentTarget */
    // Products define the executables and libraries a package produces, making them visible to other packages.
    products: [
        .library(name: "Common", targets: ["Common"]),
        .library(name: "AppBundle", targets: ["AppBundle"]),
        .executable(name: "aerospace", targets: ["Cli"])
    ],
    dependencies: [
        .package(url: "https://github.com/Kitura/BlueSocket", exact: "2.0.4")
    ],
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    targets: [
        .target(name: "Common"),
        .target(
            name: "AppBundle",
            dependencies: [
                .target(name: "Common"),
            ]
        ),
        .executableTarget(
            name: "Cli",
            dependencies: [
                .target(name: "Common"),
                .product(name: "Socket", package: "BlueSocket"),
            ]
        )
        //.testTarget(
        //    name: "AeroSpacePackageTests",
        //    dependencies: ["AeroSpacePackage"]
        //),
    ]
)
