// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TerminalTests",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "t_terminal_ghostty",
            targets: ["TerminalGhosttyTestFlows"]
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
        .executable(
            name: "t_terminal_graph",
            targets: ["TerminalGraphTesting"]
        ),
        .executable(
            name: "t_terminal_navigation",
            targets: ["TerminalNavigationTests"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/Difference", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Tokens", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/DSL", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Primitives.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Reporting.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Search.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Math.git", branch: "master"),
        .package(url: "https://github.com/leviouwendijk/Testing.git", branch: "master"),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "TerminalGhosttyTestFlows",
            dependencies: [
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "TerminalGhostty", package: "Terminal"),
            ]
        ),
        .executableTarget(
            name: "TerminalGraphTesting",
            dependencies: [
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "TerminalGraph", package: "Terminal"),
                .product(name: "Primitives", package: "Primitives"),
            ]
        ),
        .executableTarget(
            name: "TerminalReportingTesting",
            dependencies: [
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "TerminalReporting", package: "Terminal"),
                .product(name: "Reporting", package: "Reporting"),
                .product(name: "Search", package: "Search"),
                .product(name: "Math", package: "Math"),
                .product(name: "DSL", package: "DSL"),
            ]
        ),
        .executableTarget(
            name: "TerminalNavigationTests",
            dependencies: [
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "Primitives", package: "Primitives"),
                .product(name: "Testing", package: "Testing"),
            ]
        ),
        .executableTarget(
            name: "TerminalTestFlows",
            dependencies: [
                .product(name: "Terminal", package: "Terminal"),
                .product(name: "TerminalStructuredContent", package: "Terminal"),
                .product(
                    name: "DSL",
                    package: "DSL"
                ),
                .product(
                    name: "Difference",
                    package: "Difference"
                ),
                .product(name: "Tokens", package: "Tokens"),
                .product(name: "Primitives", package: "Primitives"),
            ]
        ),
    ]
)
