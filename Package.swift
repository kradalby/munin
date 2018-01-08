// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Gal",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .executable(
            name: "gal",
            targets: ["Gal"]),
        .library(
            name: "GalKit",
            targets: ["GalKit"]),
        .library(
            name: "Logger",
            targets: ["Logger"]),
        .library(
            name: "Config",
            targets: ["Config"]),
        ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        //.package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", from: "0.8.0"),
//        .package(url: "https://github.com/oarrabi/Guaka.git", from: "0.1.3"),
        .package(url: "https://github.com/onevcat/Rainbow", from: "3.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Gal",
            dependencies: [
                "GalKit",
                "Logger",
                "Config",
//                "Guaka"
                ]),
        .target(
            name: "GalKit",
            dependencies: [
                "Logger",
                "Config"
                ]),
        .target(
            name: "Logger",
            dependencies: [
                "Rainbow"
                ]),
        .target(
            name: "Config",
            dependencies: [
                "Logger"
                ]),
    ]

)
