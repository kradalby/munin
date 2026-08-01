// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-vips",
    platforms: [ .macOS(.v14)],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(name: "VIPS", targets: ["VIPS"]),
        .library(name: "VIPSIntrospection", targets: ["VIPSIntrospection"]),
        .executable(name: "vips-generator", targets: ["vips-generator"]),
    ],
    traits: [
        "FoundationSupport",
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/swiftlang/swift-subprocess.git", from: "0.2.1"),
    ],
    targets: [
        .systemLibrary(name: "Cvips",
                       pkgConfig: "vips"),
        .target(
            name: "CvipsShim",
            dependencies: [
                "Cvips"
            ]),
        // Build tool plugin that generates Swift wrappers from libvips introspection
        .plugin(
            name: "VIPSGeneratorPlugin",
            capability: .buildTool(),
            dependencies: ["vips-generator"]
        ),
        .target(
            name: "VIPS",
            dependencies: [
                "Cvips",
                "CvipsShim",
                .product(name: "Logging", package: "swift-log")
            ],
            swiftSettings: [
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableUpcomingFeature("InferIsolatedConformances"),
                .enableExperimentalFeature("Lifetimes")
            ],
            // VENDORED: upstream has `plugins: [.plugin(name: "VIPSGeneratorPlugin")]`
            // here. It is removed because the plugin builds a *host* tool that
            // links Cvips, which is unsatisfiable during a cross build. The
            // wrappers it would emit are checked in under
            // Sources/VIPS/Generated instead. See VENDORED.md.
            ),
        .target(
            name: "VIPSIntrospection",
            dependencies: [
                "Cvips",
                "CvipsShim"
            ]),
        .executableTarget(name: "vips-generator",
            dependencies: [
                "VIPSIntrospection",
                .product(name: "Subprocess", package: "swift-subprocess")
            ],
            path: "Sources/VIPSGenerator"
        ),
        .executableTarget(name: "vips-tool",
            dependencies: ["VIPS", "Cvips"]
        ),
        // VENDORED: the `VIPSTests` target is dropped here because Munin does
        // not vendor `Tests/` (48 MB of image fixtures). See VENDORED.md.
    ],
    swiftLanguageModes: [ .v6 ]
)
