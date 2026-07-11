// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Pinch",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "PinchCore"),
        .executableTarget(name: "Pinch", dependencies: ["PinchCore"]),
        .testTarget(name: "PinchCoreTests", dependencies: ["PinchCore"])
    ]
)
