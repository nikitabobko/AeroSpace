// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ShellParserGenerated",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ShellParserGenerated",
            targets: ["ShellParserGenerated"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/antlr/antlr4", exact: "4.13.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ShellParserGenerated",
            dependencies: [
                .product(name: "Antlr4Static", package: "antlr4"),
            ]
        ),
    ]
)
