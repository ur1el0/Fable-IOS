// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FableApp",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .executable(
            name: "FableApp",
            targets: ["FableApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "FableApp",
            path: "Sources"
        )
    ]
)
