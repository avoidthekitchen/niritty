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
            dependencies: [
                "NirittyWorkspaceModel",
                "NirittyGhosttyTerminal"
            ]
        ),
        .target(
            name: "NirittyGhosttyTerminal",
            dependencies: [
                .target(name: "NirittyWorkspaceModel"),
                .target(name: "GhosttyKit")
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedLibrary("c++")
            ]
        ),
        .binaryTarget(
            name: "GhosttyKit",
            path: "Vendor/ghostty/macos/GhosttyKit.xcframework"
        ),
        .testTarget(
            name: "NirittyWorkspaceModelTests",
            dependencies: ["NirittyWorkspaceModel"]
        ),
        .testTarget(
            name: "NirittyGhosttyTerminalTests",
            dependencies: ["NirittyGhosttyTerminal"]
        ),
        .testTarget(
            name: "NirittyBuildSupportTests",
            dependencies: []
        )
    ]
)
