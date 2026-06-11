// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Niritty",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "NirittyWorkspaceModel",
            targets: ["NirittyWorkspaceModel"]
        ),
        .executable(
            name: "Niritty",
            targets: ["Niritty"]
        )
    ],
    targets: [
        .target(
            name: "NirittyWorkspaceModel"
        ),
        .executableTarget(
            name: "Niritty",
            dependencies: ["NirittyWorkspaceModel"]
        ),
        .testTarget(
            name: "NirittyWorkspaceModelTests",
            dependencies: ["NirittyWorkspaceModel"]
        )
    ]
)
