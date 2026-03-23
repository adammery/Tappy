// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "InputTracker",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "InputTracker",
            path: "Sources/InputTracker"
        )
    ]
)
