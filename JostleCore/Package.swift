// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "JostleCore",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "JostleCore", targets: ["JostleCore"])
    ],
    targets: [
        .target(name: "JostleCore"),
        .testTarget(name: "JostleCoreTests", dependencies: ["JostleCore"])
    ]
)
