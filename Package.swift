// swift-tools-version:5.6
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
    .macOS(.v10_15),
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
    .package(url: "https://github.com/t089/swift-vips.git", branch: "main"),
    .package(url: "https://github.com/kradalby/SwiftExif.git", from: "0.0.7"),
    // .package(path: "../SwiftExif"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.5.2"),
    .package(url: "https://github.com/Kitura/Configuration.git", from: "3.1.0"),
    .package(url: "https://github.com/onevcat/Rainbow.git", from: "4.0.1"),
    .package(
      url: "https://github.com/apple/swift-tools-support-core.git",
      .upToNextMajor(from: "0.5.2")),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.4.0"),
  ],
  targets: [
    .executableTarget(
      name: "Munin",
      dependencies: [
        "MuninKit",
        .product(name: "Logging", package: "swift-log"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        "Configuration",
      ]
    ),
    .target(
      name: "MuninKit",
      dependencies: [
        .product(name: "SwiftToolsSupport-auto", package: "swift-tools-support-core"),
        .product(name: "Logging", package: "swift-log"),
        .product(name: "VIPS", package: "swift-vips"),
        "SwiftExif",
        "Configuration",
        "Rainbow",
      ],
      exclude: ["Templates"]
    ),
    .testTarget(
      name: "MuninTests",
      dependencies: ["Munin"]
    ),
    .testTarget(
      name: "MuninKitTests",
      dependencies: [
        "MuninKit",
        "Configuration",
      ]
    ),
  ]
)
