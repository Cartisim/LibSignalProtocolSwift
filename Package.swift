// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LibSignalProtocolSwift",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_10),
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "LibSignalProtocolSwift",
            targets: ["LibSignalProtocolSwift"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(name: "SwiftProtobuf", url: "https://github.com/apple/swift-protobuf.git", from: "1.6.0"),
        .package(name: "CCurve25519", url: "https://github.com/christophhagen/CCurve25519.git", from: "1.0.0"),
        .package(name: "Curve25519", url: "https://github.com/christophhagen/Curve25519.git", from: "2.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "LibSignalProtocolSwift",
            dependencies: ["SwiftProtobuf", "Curve25519"],
            path: "Sources"),

        .testTarget(
            name: "LibSignalProtocolSwiftTests",
            dependencies: ["LibSignalProtocolSwift"],
            path: "Tests"),
    ]
)
