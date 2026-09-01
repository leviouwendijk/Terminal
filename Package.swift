// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Terminal",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .library(
            name: "Terminal",
            targets: ["Terminal"]
        ),
        .library(
            name: "TerminalStructuredContent",
            targets: ["TerminalStructuredContent"]
        ),
        .executable(
            name: "termtest",
            targets: [
                "TerminalTestFlows"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/ANSI", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Difference", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Strings", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/DSL", branch: "master"),

    ],
    targets: [
        .target(
            name: "Terminal",
            dependencies: [
                .product(name: "ANSI", package: "ANSI"),
                .product(name: "Difference", package: "Difference"),
                .product(name: "Strings", package: "Strings"),
            ],
        ),
        .target(
            name: "TerminalStructuredContent",
            dependencies: [
                "Terminal",
                .product(
                    name: "DSL",
                    package: "DSL"
                ),
            ]
        ),
        .executableTarget(
            name: "TerminalTestFlows",
            dependencies: [
                "Terminal",
                "TerminalStructuredContent",
                .product(
                    name: "DSL",
                    package: "DSL"
                ),
                .product(
                    name: "Difference",
                    package: "Difference"
                ),
            ]
        ),
    ]
)
