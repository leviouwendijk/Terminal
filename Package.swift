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
        .executable(
            name: "termtest",
            targets: [
                "TerminalTestFlows"
            ]
        ),
        .executable(
            name: "t_terminal_reporting",
            targets: ["TerminalReportingTesting"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/ANSI", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Difference", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Strings", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/DSL", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Reporting.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Search.git", branch: "master"),
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
            name: "TerminalReporting",
            dependencies: [
                "Terminal",
                "TerminalStructuredContent",
                .product(name: "Reporting", package: "Reporting"),
                .product(name: "Search", package: "Search"),
            ]
        ),
        .executableTarget(
            name: "TerminalReportingTesting",
            dependencies: [
                "Terminal",
                "TerminalReporting",
                .product(name: "Reporting", package: "Reporting"),
                .product(name: "Search", package: "Search"),
                .product(name: "DSL", package: "DSL"),
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
