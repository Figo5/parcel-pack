// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ParcelPack",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ParcelCore", targets: ["ParcelCore"]),
        .executable(name: "ParcelPack", targets: ["ParcelPackApp"])
    ],
    targets: [
        .target(name: "ParcelCore"),
        .executableTarget(name: "ParcelPackApp", dependencies: ["ParcelCore"]),
        .testTarget(name: "ParcelCoreTests", dependencies: ["ParcelCore"]),
        .testTarget(name: "ParcelAppTests", dependencies: ["ParcelPackApp", "ParcelCore"])
    ]
)
