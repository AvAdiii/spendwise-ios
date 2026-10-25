// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SpendCore",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "SpendCore", targets: ["SpendCore"]),
    ],
    targets: [
        .target(name: "SpendCore"),
        .testTarget(name: "SpendCoreTests", dependencies: ["SpendCore"]),
    ]
)
