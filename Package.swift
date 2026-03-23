// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Tappy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Tappy",
            path: "Sources/InputTracker"
        )
    ]
)
