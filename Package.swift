// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NimbusCore",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "NimbusShared", targets: ["NimbusShared"])
    ],
    targets: [
        .target(
            name: "NimbusShared",
            path: "NimbusShared",
            exclude: ["NimbusShared.h"]
        ),
        .testTarget(
            name: "NimbusTests",
            dependencies: ["NimbusShared"],
            path: "NimbusTests"
        )
    ]
)
