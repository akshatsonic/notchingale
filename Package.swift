// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Notchingale",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Notchingale",
            path: "Sources/Notchingale",
            resources: [
                .copy("Resources/logo.svg")
            ]
        )
    ]
)
