// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ProgressQuest",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ProgressQuest",
            resources: [.copy("Resources")]
        )
    ]
)
