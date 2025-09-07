// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PhotoPin",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PhotoPin", targets: ["PhotoPin"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PhotoPin",
            dependencies: [],
            path: "Sources"
        )
    ]
)
