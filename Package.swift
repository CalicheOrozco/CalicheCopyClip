// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "CalicheCopyClip",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "CalicheCopyClip",
            path: "Sources/CalicheCopyClip"
        )
    ]
)
