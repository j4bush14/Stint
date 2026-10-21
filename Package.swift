// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Stint",
    platforms: [.macOS("27.0")],
    targets: [
        .executableTarget(
            name: "Stint",
            path: "Sources/Stint",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "StintTests",
            dependencies: ["Stint"],
            path: "Tests/StintTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
