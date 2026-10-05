// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PicoCore",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "PicoCore", targets: ["PicoCore"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0"),
    ],
    targets: [
        .target(
            name: "PicoCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        // Harnais de tests provisoire : XCTest et Swift Testing ne sont pas
        // livres avec les Command Line Tools. A migrer vers un testTarget
        // Swift Testing une fois Xcode installe (voir docs/tests.md).
        .executableTarget(
            name: "picocore-check",
            dependencies: ["PicoCore"]
        ),
    ]
)
