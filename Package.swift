// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Sill",
    platforms: [.macOS(.v15)], // Translation 프레임워크(TranslationSession) 요구
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0")
    ],
    targets: [
        .executableTarget(
            name: "Sill",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            path: "Sources/Sill"
        )
    ],
    // tools 6.0로 올렸지만 strict concurrency 전환은 별도 작업 — 언어 모드는 v5 유지
    swiftLanguageModes: [.v5]
)
