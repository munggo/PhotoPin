// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GeoTagger",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "GeoTagger", targets: ["GeoTagger"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "GeoTagger",
            dependencies: [],
            path: "Sources",
            resources: [
                .copy("geotag.py")
            ]
        )
    ]
)
