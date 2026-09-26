// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tempo",
    platforms: [.macOS(.v15)],
    targets: [
        .target(name: "TempoCore"),
        .executableTarget(name: "Tempo", dependencies: ["TempoCore"]),
        .testTarget(name: "TempoCoreTests", dependencies: ["TempoCore"]),
    ],
    swiftLanguageModes: [.v5]
)
