// swift-tools-version: 6.0
// Construction de l'app via SwiftPM (sans Xcode) : `make run`.
// Le projet Xcode (project.yml) reste la reference pour les extensions
// (widgets, App Intents) une fois Xcode installe.
import PackageDescription

let package = Package(
    name: "PicoApp",
    platforms: [.macOS("26.0")],
    dependencies: [
        .package(path: "Packages/PicoCore"),
    ],
    targets: [
        .executableTarget(
            name: "Pico",
            dependencies: [
                .product(name: "PicoCore", package: "PicoCore"),
            ],
            path: "Pico",
            exclude: ["Resources"],
            swiftSettings: [.unsafeFlags(["-Xfrontend", "-enable-experimental-feature", "-Xfrontend", "StrictConcurrency"])]
        ),
    ]
)
