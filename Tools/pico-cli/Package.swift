// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "pico-cli",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(path: "../../Packages/PicoCore"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
    ],
    targets: [
        .executableTarget(
            name: "pico",
            dependencies: [
                .product(name: "PicoCore", package: "PicoCore"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
    ]
)
