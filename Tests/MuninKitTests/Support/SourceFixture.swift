import Foundation

/// Stages a subset of the checked-in `example/album` tree into a temporary
/// directory so tests can freely mutate the source without polluting the
/// repository.
///
/// Typical use:
///
/// ```swift
/// let fixture = try SourceFixture.stageAll()
/// defer { fixture.cleanup() }
///
/// let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
/// try await harness.build()
///
/// try fixture.removePhoto(inAlbum: "2017/2017-12-22 Juleferie",
///                          named: "20171222-132846-20171222-IMG_5259.jpg")
/// try await harness.build()
/// ```
///
/// The fixture only ever modifies files under its own temp directory. It
/// never writes to the repo-tracked `example/album` tree.
final class SourceFixture {

  /// Root of the staged source tree. Always an absolute path.
  let sourceRoot: String

  /// The on-disk path from which this fixture was copied. Kept for
  /// diagnostics; callers shouldn't need it.
  let originRoot: String

  private let tempRoot: String
  private let fm: FileManager

  private init(tempRoot: String, sourceRoot: String, originRoot: String) {
    self.tempRoot = tempRoot
    self.sourceRoot = sourceRoot
    self.originRoot = originRoot
    self.fm = FileManager.default
  }

  // MARK: - Construction

  /// Stage the full `example/album` tree. Fast enough for most tests; use
  /// ``stage(albums:)`` when you only need a subset.
  static func stageAll(originRoot: String = "example/album") throws -> SourceFixture {
    try stage(albums: nil, originRoot: originRoot)
  }

  /// Stage only the named top-level sub-albums (e.g. `["Misc"]`). Passing
  /// `nil` stages the whole origin.
  static func stage(
    albums: [String]?,
    originRoot: String = "example/album"
  ) throws -> SourceFixture {
    let fm = FileManager.default
    let tmp = fm.temporaryDirectory
      .appendingPathComponent("munin-fixture-\(UUID().uuidString)", isDirectory: true)
    try fm.createDirectory(at: tmp, withIntermediateDirectories: true)

    let source = tmp.appendingPathComponent("source", isDirectory: true)
    try fm.createDirectory(at: source, withIntermediateDirectories: true)

    // Resolve origin relative to CWD so tests work when invoked from the
    // repo root (which is how `swift test` runs them).
    let cwd = fm.currentDirectoryPath
    let originAbsolute = originRoot.hasPrefix("/") ? originRoot : cwd + "/" + originRoot

    if let albums {
      for album in albums {
        let src = URL(fileURLWithPath: originAbsolute).appendingPathComponent(album)
        let dst = source.appendingPathComponent(album)
        try copyItemCreatingIntermediates(at: src, to: dst)
      }
    } else {
      let children = try fm.contentsOfDirectory(atPath: originAbsolute)
      for child in children {
        let src = URL(fileURLWithPath: originAbsolute).appendingPathComponent(child)
        let dst = source.appendingPathComponent(child)
        try copyItemCreatingIntermediates(at: src, to: dst)
      }
    }

    return SourceFixture(
      tempRoot: tmp.path, sourceRoot: source.path, originRoot: originAbsolute)
  }

  /// Remove the temp directory. Safe to call multiple times and from
  /// `deinit`.
  func cleanup() {
    try? fm.removeItem(atPath: tempRoot)
  }

  deinit {
    cleanup()
  }

  // MARK: - Mutation API

  /// Copy a source image file into an album. `sourceImagePath` must be an
  /// existing file somewhere on disk (typically under
  /// `example/album/...` or another fixture's tree).
  ///
  /// - Parameters:
  ///   - albumRelativePath: album path relative to ``sourceRoot``.
  ///   - sourceImagePath: absolute path of the file to copy in.
  ///   - as: override the destination file name; defaults to the source's
  ///     last path component.
  func addPhoto(
    toAlbum albumRelativePath: String,
    fromSourceFile sourceImagePath: String,
    as name: String? = nil
  ) throws {
    let dstDir = absolutePath(for: albumRelativePath)
    var isDir: ObjCBool = false
    if !fm.fileExists(atPath: dstDir, isDirectory: &isDir) {
      try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
    }
    let dstName = name ?? URL(fileURLWithPath: sourceImagePath).lastPathComponent
    let dst = dstDir + "/" + dstName
    if fm.fileExists(atPath: dst) {
      try fm.removeItem(atPath: dst)
    }
    try fm.copyItem(atPath: sourceImagePath, toPath: dst)
  }

  /// Delete a single photo from an album.
  func removePhoto(inAlbum albumRelativePath: String, named name: String) throws {
    let path = absolutePath(for: albumRelativePath) + "/" + name
    try fm.removeItem(atPath: path)
  }

  /// Delete an entire sub-album directory and everything inside it.
  func removeAlbum(_ albumRelativePath: String) throws {
    try fm.removeItem(atPath: absolutePath(for: albumRelativePath))
  }

  /// Rename an album in place.
  func renameAlbum(from oldRelative: String, to newRelative: String) throws {
    try fm.moveItem(
      atPath: absolutePath(for: oldRelative), toPath: absolutePath(for: newRelative))
  }

  /// Bump the modification time on a photo to "now" without changing its
  /// bytes. Used to exercise the "mtime-only change" behaviour.
  func touchPhoto(inAlbum albumRelativePath: String, named name: String) throws {
    let path = absolutePath(for: albumRelativePath) + "/" + name
    guard fm.fileExists(atPath: path) else {
      throw FixtureError.fileMissing(path: path)
    }
    try fm.setAttributes([.modificationDate: Date()], ofItemAtPath: path)
  }

  /// Replace a photo's bytes with the contents of another source file
  /// (keeping the destination name). Both mtime and bytes change.
  func replacePhoto(
    inAlbum albumRelativePath: String,
    named name: String,
    withSourceFile sourceImagePath: String
  ) throws {
    let dst = absolutePath(for: albumRelativePath) + "/" + name
    if fm.fileExists(atPath: dst) {
      try fm.removeItem(atPath: dst)
    }
    try fm.copyItem(atPath: sourceImagePath, toPath: dst)
  }

  /// Locate a photo under the staged origin for copy-source use in
  /// ``addPhoto(toAlbum:fromSourceFile:as:)``.
  func originPhoto(_ relativePath: String) -> String {
    originRoot + "/" + relativePath
  }

  // MARK: - Bulk queries and mutators

  /// Every staged photo path, relative to ``sourceRoot``. Sorted for
  /// determinism so `pickRandomPhotos(count:seed:)` returns the same
  /// subset on macOS and Linux.
  var allPhotos: [String] {
    let extensions: Set<String> = ["jpg", "jpeg", "JPG", "JPEG"]
    let rootURL = URL(fileURLWithPath: sourceRoot)
    guard let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: nil)
    else { return [] }

    var out: [String] = []
    let prefix = sourceRoot.hasSuffix("/") ? sourceRoot : sourceRoot + "/"
    for case let url as URL in enumerator {
      guard extensions.contains(url.pathExtension) else { continue }
      let absolute = url.path
      if absolute.hasPrefix(prefix) {
        out.append(String(absolute.dropFirst(prefix.count)))
      }
    }
    return out.sorted()
  }

  /// Pick `count` photos deterministically from ``allPhotos`` using a
  /// SplitMix64-seeded PRNG. Same `seed` produces the same subset on
  /// every run / platform.
  ///
  /// - Parameters:
  ///   - count: number of photos to select. Capped at `allPhotos.count`.
  ///   - seed: 64-bit seed; any value is fine, pick a memorable constant
  ///     per scenario so failures are reproducible.
  func pickRandomPhotos(count: Int, seed: UInt64) -> [String] {
    let pool = allPhotos
    let n = min(count, pool.count)
    guard n > 0 else { return [] }
    // Fisher-Yates partial shuffle. Deterministic RNG so cross-platform
    // stable.
    var rng = SplitMix64(state: seed)
    var indices = Array(0..<pool.count)
    for i in 0..<n {
      let j = Int(rng.next() % UInt64(pool.count - i)) + i
      indices.swapAt(i, j)
    }
    return indices.prefix(n).map { pool[$0] }.sorted()
  }

  /// Bump the mtime on every photo in `relativePaths`.
  func touchPhotos(_ relativePaths: [String]) throws {
    let now = Date()
    for relative in relativePaths {
      let absolute = absolutePath(for: relative)
      guard fm.fileExists(atPath: absolute) else {
        throw FixtureError.fileMissing(path: absolute)
      }
      try fm.setAttributes([.modificationDate: now], ofItemAtPath: absolute)
    }
  }

  /// Delete every photo in `relativePaths`. Leaves empty directories in
  /// place (Munin's clean sweeps those).
  func removePhotos(_ relativePaths: [String]) throws {
    for relative in relativePaths {
      try fm.removeItem(atPath: absolutePath(for: relative))
    }
  }

  /// Replace every photo in `relativePaths` with bytes drawn from
  /// `donorPool` in round-robin order. `donorPool` is a list of absolute
  /// paths (typically obtained via ``originPhoto(_:)``).
  ///
  /// If the donor pool is smaller than `relativePaths` the pool is
  /// cycled; a single donor therefore produces identical replacement
  /// bytes across multiple targets, which is a legitimate "edit all"
  /// scenario.
  func replacePhotos(_ relativePaths: [String], withDonorPool donorPool: [String]) throws {
    guard !donorPool.isEmpty else {
      throw FixtureError.fileMissing(path: "<empty donor pool>")
    }
    for (idx, relative) in relativePaths.enumerated() {
      let donor = donorPool[idx % donorPool.count]
      let dst = absolutePath(for: relative)
      if fm.fileExists(atPath: dst) {
        try fm.removeItem(atPath: dst)
      }
      try fm.copyItem(atPath: donor, toPath: dst)
    }
  }

  /// Copy a staged sub-album under a new top-level name. The clone lives
  /// at `sourceRoot/<asNewName>` and contains the same photos as the
  /// origin. Used for "add album" scenarios without spinning up a second
  /// fixture.
  func cloneAlbum(originRelative: String, asNewName: String) throws {
    let src = absolutePath(for: originRelative)
    let dst = absolutePath(for: asNewName)
    guard fm.fileExists(atPath: src) else {
      throw FixtureError.fileMissing(path: src)
    }
    if fm.fileExists(atPath: dst) {
      try fm.removeItem(atPath: dst)
    }
    try fm.copyItem(atPath: src, toPath: dst)
  }

  // MARK: - Helpers

  private func absolutePath(for relative: String) -> String {
    relative.hasPrefix("/") ? relative : sourceRoot + "/" + relative
  }

  private static func copyItemCreatingIntermediates(at src: URL, to dst: URL) throws {
    let fm = FileManager.default
    try fm.createDirectory(
      at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
    try fm.copyItem(at: src, to: dst)
  }
}

/// Deterministic 64-bit PRNG (Sebastiano Vigna's SplitMix64). Tiny and
/// pure-Swift so `pickRandomPhotos(count:seed:)` produces identical
/// subsets on every platform — unlike `SystemRandomNumberGenerator`
/// which is host-specific.
private struct SplitMix64 {
  var state: UInt64

  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

enum FixtureError: Error, CustomStringConvertible {
  case fileMissing(path: String)

  var description: String {
    switch self {
    case .fileMissing(let path):
      return "Fixture file missing: \(path)"
    }
  }
}
