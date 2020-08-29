// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

// https://theswiftdev.com/the-swift-package-manifest-file/

import PackageDescription

let package = Package(
  name: "Munin",
  platforms: [
    .macOS(.v10_12)
    // .linux
  ],
  products: [
    // Products define the executables and libraries produced by a package, and make them visible to other packages.
    .executable(
      name: "munin",
      targets: ["Munin"]
    ),
    .library(
      name: "MuninKit",
      targets: ["MuninKit"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/kylef/Commander.git", from: "0.9.1"),
    .package(url: "https://github.com/kradalby/Config.swift.git", from: "0.0.2"),
    .package(url: "https://github.com/twostraws/SwiftGD.git", from: "2.5.0"),
    .package(url: "https://github.com/kradalby/SwiftExif.git", from: "0.0.4"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.4.0"),
    .package(
      url: "https://github.com/apple/swift-tools-support-core.git",
      .upToNextMajor(from: "0.1.10")),
    // .package(url: "https://github.com/Ponyboy47/swift-log-file.git", .branch("master")),

    // .package(path: "../SwiftExif"),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(
      name: "Munin",
      dependencies: [
        "MuninKit",
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Config", package: "Config.swift"),
        "Commander",
      ]
    ),
    .target(
      name: "MuninKit",
      dependencies: [
        .product(name: "SwiftToolsSupport", package: "swift-tools-support-core"),
        // .product(name: "FileLogging", package: "swift-log-file"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "Config", package: "Config.swift"),
        "SwiftGD",
        "SwiftExif",
      ]
    ),
    .testTarget(
      name: "MuninTests",
      dependencies: ["Munin"]
    ),
    .testTarget(
      name: "MuninKitTests",
      dependencies: ["MuninKit"]
    ),
  ]
)
