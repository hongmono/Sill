// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ScreenshotStack",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ScreenshotStack", path: "Sources/ScreenshotStack")
    ]
)
