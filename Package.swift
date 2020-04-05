// swift-tools-version:4.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Munin",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .executable(
            name: "munin",
            targets: ["Munin"]),
        .library(
            name: "MuninKit",
            targets: ["MuninKit"])
        ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
        .package(url: "https://github.com/kylef/Commander.git", from: "0.9.1"),
        .package(url: "https://github.com/kradalby/Logger.swift.git", from: "0.0.6"),
        .package(url: "https://github.com/kradalby/Config.swift.git", from: "0.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Munin",
            dependencies: [
                "MuninKit",
                "Logger",
                "Config",
                "Commander"
                ]),
        .target(
            name: "MuninKit",
            dependencies: [
                "Logger",
                "Config"
                ])
    ]

)
