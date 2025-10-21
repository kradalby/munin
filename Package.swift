// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Dynamic Dependencies for Munin (Ubuntu/Debian systems)
//
// APT packages required:
// - libgd-dev (libgd3)
// - libiptcdata0-dev (libiptcdata0)  
// - libexif-dev (libexif12)
// - libvips-dev (libvips42)
// - libglib2.0-dev (libglib2.0-0)
// - libjpeg-dev (libjpeg8)
// - libpng-dev (libpng16-16)
// - zlib1g-dev (zlib1g)
//
// Install with: sudo apt install libgd-dev libiptcdata0-dev libexif-dev libvips-dev
//
// NIX packages (for flake-based development):
// - gd
// - libiptcdata
// - libexif
// - vips
// - glib
// - libjpeg
// - libpng
// - zlib
//
// Static build option available: `swift build --static-swift-stdlib -c release`
// - Eliminates Swift runtime dependencies (13 .so files)
// - Binary size: ~73MB (vs 7MB dynamic)
// - Requires only C library dependencies listed above

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
