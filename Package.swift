// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

// https://theswiftdev.com/the-swift-package-manifest-file/

import PackageDescription

var linkerSettings: [LinkerSetting]? {
  #if os(Linux)
    return [
      .linkedLibrary("gd"),
      .linkedLibrary("iptcdata"),
      .linkedLibrary("exif"),
    ]
  #else
    return nil
  #endif
}

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
    .package(url: "https://github.com/kradalby/Config.swift.git", from: "0.0.3"),
    .package(url: "https://github.com/kradalby/MagickWand.git", .branch("main")),
    .package(url: "https://github.com/kradalby/SwiftExif.git", from: "0.0.5"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.4.2"),
    .package(url: "https://github.com/crspybits/swift-log-file.git", from: "0.1.0"),
    // .package(
    //   url: "https://github.com/apple/swift-atomics.git",
    //   .upToNextMinor(from: "0.0.1")
    // ),
    .package(
      url: "https://github.com/apple/swift-tools-support-core.git",
      .upToNextMajor(from: "0.2.0")),
    // .package(path: "../MagickWand"),

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
      // linkerSettings: linkerSettings
    ),
    .target(
      name: "MuninKit",
      dependencies: [
        .product(name: "SwiftToolsSupport", package: "swift-tools-support-core"),
        .product(name: "Config", package: "Config.swift"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "FileLogging", package: "swift-log-file"),
        // .product(name: "Atomics", package: "swift-atomics"),
        "MagickWand",
        "SwiftExif",
      ],
      exclude: ["Templates"]
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
