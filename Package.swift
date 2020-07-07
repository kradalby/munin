// swift-tools-version:5.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

// https://theswiftdev.com/the-swift-package-manifest-file/

import PackageDescription

let package = Package(
  name: "Munin",
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
    .package(url: "https://github.com/kradalby/Logger.swift.git", from: "0.0.7"),
    .package(url: "https://github.com/kradalby/Config.swift.git", from: "0.0.2"),
    .package(url: "https://github.com/twostraws/SwiftGD.git", from: "2.5.0"),
    .package(url: "https://github.com/kradalby/SwiftExif.git", from: "0.0.2"),
    // .package(path: "../SwiftExif"),
  ],
  targets: [
    // Targets are the basic building blocks of a package. A target can define a module or a test suite.
    // Targets can depend on other targets in this package, and on products in packages which this package depends on.
    .target(
      name: "Munin",
      dependencies: [
        "MuninKit",
        .product(name: "Logger", package: "Logger.swift"),
        .product(name: "Config", package: "Config.swift"),
        "Commander",
      ]
    ),
    .target(
      name: "MuninKit",
      dependencies: [
        .product(name: "Logger", package: "Logger.swift"),
        .product(name: "Config", package: "Config.swift"),
        "SwiftGD",
        "SwiftExif",
      ]
    ),
    .testTarget(
      name: "MuninTests",
      dependencies: ["Munin"]
    ),
  ]
)
