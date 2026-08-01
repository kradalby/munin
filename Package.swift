// swift-tools-version:6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "Munin",
  platforms: [
    .macOS(.v14)
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
    .package(url: "https://github.com/kradalby/SwiftExif.git", from: "0.1.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.12.0"),
    // vapor/console-kit provides the progress/activity indicator UI that
    // replaced swift-tools-support-core's PercentProgressAnimation.
    .package(url: "https://github.com/vapor/console-kit.git", from: "4.16.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.1"),
    // apple/swift-system provides FilePath for typed path handling. Used
    // internally in MuninKit's `Paths` helpers; public API is still String.
    .package(url: "https://github.com/apple/swift-system.git", from: "1.6.4"),
    // apple/swift-crypto provides SHA256 on Linux (mirroring CryptoKit's API
    // on Darwin). Used both in MuninKit proper (for source-file content
    // hashing) and in the test support layer (for filesystem snapshots).
    .package(url: "https://github.com/apple/swift-crypto.git", "3.0.0"..<"5.0.0"),
  ],
  targets: [
    // libvips itself. `pkgConfig` is read by SwiftPM's own .pc parser, not by
    // pkg-config(1) — that is why the musl sysroot ships a flattened vips.pc
    // with no `Requires:` (see build/musl-sysroot/build.sh).
    .systemLibrary(
      name: "Cvips",
      pkgConfig: "vips",
      providers: [.apt(["libvips-dev"]), .brew(["vips"])]
    ),
    // Fixed-arity wrappers for the libvips operations Munin performs. They
    // exist only because those entry points are NULL-terminated C variadics,
    // which Swift cannot call. See Sources/MuninVipsShim/include.
    .target(
      name: "MuninVipsShim",
      dependencies: ["Cvips"]
    ),
    // The Swift binding. A target of its own rather than a file in MuninKit
    // so that touching libvips requires `import MuninVips`: MuninKit depends
    // on this and not on Cvips/MuninVipsShim, and ImagingFacadeTests fails
    // any import outside the Imaging facade.
    .target(
      name: "MuninVips",
      dependencies: ["Cvips", "MuninVipsShim"]
    ),
    .executableTarget(
      name: "Munin",
      dependencies: [
        "MuninKit",
        .product(name: "Logging", package: "swift-log"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]
    ),
    .target(
      name: "MuninKit",
      dependencies: [
        .product(name: "Logging", package: "swift-log"),
        "MuninVips",
        .product(name: "ConsoleKitTerminal", package: "console-kit"),
        .product(name: "SystemPackage", package: "swift-system"),
        .product(name: "Crypto", package: "swift-crypto"),
        "SwiftExif",
      ]
    ),
    .testTarget(
      name: "MuninTests",
      dependencies: ["Munin"]
    ),
    .testTarget(
      name: "MuninKitTests",
      dependencies: [
        "MuninKit",
        .product(name: "Crypto", package: "swift-crypto"),
      ]
    ),
  ]
)
