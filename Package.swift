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
            name: "terminaltest",
            targets: [
                "terminaltest"
            ]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/leviouwendijk/ANSI", branch: "master"),

    ],
    targets: [
        .target(
            name: "Terminal",
            dependencies: [
                .product(name: "ANSI", package: "ANSI"),
            ],
        ),
        .executableTarget(
            name: "terminaltest",
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
