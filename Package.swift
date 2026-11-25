// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ScreenSide",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "ScreenSide", path: "Sources/ScreenSide")
    ]
)
