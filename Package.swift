// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Terminal",
    platforms: [
        .macOS(.v13)
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
        .library(
            name: "TerminalReporting",
            targets: ["TerminalReporting"]
        ),
        .library(
            name: "TerminalGraph",
            targets: ["TerminalGraph"]
        ),
        .executable(
            name: "termtest",
            targets: [
                "TerminalTestFlows"
            ]
        ),
        .executable(
            name: "diffpreview",
            targets: ["TerminalDifferencePreview"]
        ),
        .executable(
            name: "t_terminal_reporting",
            targets: ["TerminalReportingTesting"]
        ),
        .executable(
            name: "t_terminal_graph",
            targets: ["TerminalGraphTesting"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/ANSI", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Difference", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Strings", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/DSL", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Reporting.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Search.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Math.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Clipboard", branch: "master"),
    ],
    targets: [
        .target(
            name: "Terminal",
            dependencies: [
                .product(name: "ANSI", package: "ANSI"),
                .product(name: "Difference", package: "Difference"),
                .product(name: "Strings", package: "Strings"),
                .product(name: "Clipboard", package: "Clipboard"),
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
        .target(
            name: "TerminalGraph",
            dependencies: [
                "Terminal",
                .product(name: "Primitives", package: "Primitives"),
            ]
        ),
        .target(
            name: "TerminalReporting",
            dependencies: [
                "Terminal",
                "TerminalStructuredContent",
                .product(name: "Reporting", package: "Reporting"),
                .product(name: "Search", package: "Search"),
                .product(name: "Math", package: "Math"),
            ]
        ),
        .executableTarget(
            name: "TerminalGraphTesting",
            dependencies: [
                "Terminal",
                "TerminalGraph",
                .product(name: "Primitives", package: "Primitives"),
            ]
        ),
        .executableTarget(
            name: "TerminalReportingTesting",
            dependencies: [
                "Terminal",
                "TerminalReporting",
                .product(name: "Reporting", package: "Reporting"),
                .product(name: "Search", package: "Search"),
                .product(name: "Math", package: "Math"),
                .product(name: "DSL", package: "DSL"),
            ]
        ),
        .executableTarget(
            name: "TerminalDifferencePreview",
            dependencies: [
                "Terminal",
                .product(name: "Difference", package: "Difference")
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
