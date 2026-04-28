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
        .executableTarget(
            name: "TerminalTestFlows",
            dependencies: [
                "Terminal"
            ]
        ),
        // .testTarget(
        //     name: "TerminalTests",
        //     dependencies: ["Terminal"]
        // ),
    ]
)
