import Foundation

@testable import MuninKit

/// Bundles a source tree, an output tree, and a configured `Context` so
/// tests can run `Gallery.load(...)` / `Gallery.build(...)` in two lines.
///
/// Each harness owns a unique temp output directory and cleans it up on
/// destruction. The source tree is **not** owned (it typically comes from
/// a ``SourceFixture``).
///
/// ```swift
/// let fixture = try SourceFixture.stageAll()
/// defer { fixture.cleanup() }
/// let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
/// defer { harness.cleanup() }
///
/// let gallery = try await harness.load()
/// try await gallery.build(ctx: harness.ctx, jsonOnly: false)
/// ```
final class GalleryHarness {

  let sourceRoot: String
  let outputRoot: String
  let name: String
  let config: GalleryConfiguration
  let ctx: Context

  /// Absolute path of the root album as written by Munin
  /// (i.e. `<outputRoot>/<name>`). This is where `index.json`, `stats.json`
  /// and the nested album folders land.
  var outputGalleryRoot: String {
    outputRoot + "/" + name
  }

  /// Create a harness pointing at the given source and a fresh output
  /// tempdir.
  ///
  /// - Parameters:
  ///   - sourceRoot: absolute path to a staged source album tree.
  ///   - name: gallery name; also the sub-directory name under the output
  ///     root.
  ///   - resolutions: thumbnail sizes to render. Defaults to a two-size set
  ///     (`180`, `340`) because larger sets slow down VIPS without
  ///     improving test coverage.
  ///   - peopleFiles: optional list of JSON files providing people names.
  ///   - concurrency: VIPS/read concurrency. Defaults to 1 to keep output
  ///     deterministic and avoid stressing the test host.
  init(
    sourceRoot: String,
    name: String = "root",
    resolutions: [Int] = [180, 340],
    peopleFiles: [String] = [],
    concurrency: Int = 1
  ) {
    VIPSSetup.ensure()

    self.sourceRoot = sourceRoot
    self.name = name

    let fm = FileManager.default
    let tempDir = fm.temporaryDirectory
      .appendingPathComponent("munin-harness-\(UUID().uuidString)", isDirectory: true)
    // Fail hard: if we can't create the output dir we can't test anything
    // meaningful.
    try? fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
    self.outputRoot = tempDir.path

    let manager = ConfigurationManager()
    manager.load([
      "name": name,
      "people": [],
      "peopleFiles": peopleFiles,
      "resolutions": resolutions,
      "jpegCompression": 0.1,
      "sourceFolder": sourceRoot,
      "targetFolder": outputRoot,
      "fileExtensions": ["jpg", "jpeg", "JPG", "JPEG"],
      "diff": false,
      "progress": false,
      "concurrency": concurrency,
    ])
    self.config = GalleryConfiguration(manager)
    self.ctx = Context(config: config)
  }

  /// Remove the output directory. Called from `deinit`; safe to call
  /// multiple times.
  func cleanup() {
    try? FileManager.default.removeItem(atPath: outputRoot)
  }

  deinit {
    cleanup()
  }

  /// Load the gallery (input + any existing output), without writing.
  func load() async throws -> Gallery {
    try await Gallery.load(ctx: ctx)
  }

  /// Convenience wrapper around `Gallery.load` followed by `Gallery.build`.
  ///
  /// - Parameter jsonOnly: forwarded to `Gallery.build(ctx:jsonOnly:)`.
  @discardableResult
  func build(jsonOnly: Bool = false) async throws -> Gallery {
    let gallery = try await Gallery.load(ctx: ctx)
    try await gallery.build(ctx: ctx, jsonOnly: jsonOnly)
    return gallery
  }

  /// Capture a snapshot of the output tree. Fails the test caller if the
  /// directory can't be walked.
  func snapshotOutput() throws -> FilesystemSnapshot {
    try FilesystemSnapshot.capture(at: outputRoot)
  }

  /// Capture a snapshot of the source tree. Useful for asserting that the
  /// source side is untouched after a build.
  func snapshotSource() throws -> FilesystemSnapshot {
    try FilesystemSnapshot.capture(at: sourceRoot)
  }
}
