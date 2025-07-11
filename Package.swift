// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

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
    .macOS(.v13),
  ],
  products: [
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
    .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
    .package(url: "https://github.com/onevcat/Rainbow.git", from: "4.0.1"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
  ],
  targets: [
    .executableTarget(
      name: "Munin",
      dependencies: [
        "MuninKit",
        .product(name: "Logging", package: "swift-log"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      linkerSettings: linkerSettings
    ),
    .target(
      name: "MuninKit",
      dependencies: [
        .product(name: "Logging", package: "swift-log"),
        .product(name: "VIPS", package: "swift-vips"),
        "SwiftExif",
        "Rainbow",
      ],
      exclude: ["Templates"],
      linkerSettings: linkerSettings
    ),
    .testTarget(
      name: "MuninTests",
      dependencies: ["Munin"]
    ),
    .testTarget(
      name: "MuninKitTests",
      dependencies: [
        "MuninKit",
      ]
    ),
  ]
)
