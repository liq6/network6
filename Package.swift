// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "Network6",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Network6Core",
            targets: ["Network6Core"]
        ),
        .executable(
            name: "network6",
            targets: ["Network6CLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0")
    ],
    targets: [
        .target(
            name: "Network6Core"
        ),
        .executableTarget(
            name: "Network6CLI",
            dependencies: [
                "Network6Core",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "Network6CoreTests",
            dependencies: ["Network6Core"]
        )
    ]
)
