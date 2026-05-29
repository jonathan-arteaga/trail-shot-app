// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TrailShot",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TrailShot", targets: ["TrailShot"])
    ],
    targets: [
        .executableTarget(name: "TrailShot"),
        .testTarget(
            name: "TrailShotTests",
            dependencies: ["TrailShot"]
        )
    ]
)
