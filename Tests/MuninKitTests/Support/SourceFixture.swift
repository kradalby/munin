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
  ///
  /// Throws ``FixtureError/destinationFolded(path:)`` if the copy replaced
  /// a *different* directory entry instead of creating a new one. That is
  /// what a case-insensitive or normalization-insensitive volume does
  /// (APFS is both): `sample.JPG` lands on top of `sample.jpg`, the two
  /// files a collision test asked for are one file, and the assertions
  /// downstream would be made against a fixture that was never built.
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

    try materialising(dstName, in: dstDir) {
      if fm.fileExists(atPath: dst) {
        try fm.removeItem(atPath: dst)
      }
      try fm.copyItem(atPath: sourceImagePath, toPath: dst)
    }
  }

  /// Copy a source image into an album with an IPTC keyword block spliced
  /// in, so a test can exercise the metadata-derived half of Munin's
  /// output namespace without an EXIF/IPTC writer on the host (neither
  /// exiftool nor exiv2 is a dependency of this project).
  ///
  /// Writes a minimal Photoshop APP13 segment — the `8BIM` resource
  /// `0x0404` holding IIM record 2 datasets — immediately after the JPEG's
  /// SOI marker, which is where `libiptcdata` looks; that is the library
  /// SwiftExif reads IPTC through. Everything else about the file is
  /// unchanged, so it still decodes and still carries its original EXIF.
  func addPhoto(
    toAlbum albumRelativePath: String,
    fromSourceFile sourceImagePath: String,
    as name: String,
    iptcKeywords: [String]
  ) throws {
    let dstDir = absolutePath(for: albumRelativePath)
    var isDir: ObjCBool = false
    if !fm.fileExists(atPath: dstDir, isDirectory: &isDir) {
      try fm.createDirectory(atPath: dstDir, withIntermediateDirectories: true)
    }
    let dst = dstDir + "/" + name

    let original = try Data(contentsOf: URL(fileURLWithPath: sourceImagePath))
    guard original.count > 2, original[original.startIndex] == 0xFF,
      original[original.startIndex + 1] == 0xD8
    else {
      throw FixtureError.notAJPEG(path: sourceImagePath)
    }

    var withKeywords = Data(original.prefix(2))
    withKeywords.append(Self.iptcKeywordSegment(iptcKeywords))
    withKeywords.append(original.dropFirst(2))

    try materialising(name, in: dstDir) {
      if fm.fileExists(atPath: dst) {
        try fm.removeItem(atPath: dst)
      }
      try withKeywords.write(to: URL(fileURLWithPath: dst))
    }
  }

  /// A JPEG APP13 segment carrying `keywords` as IIM 2:25 datasets.
  private static func iptcKeywordSegment(_ keywords: [String]) -> Data {
    var iim = Data()
    // 2:00 record version. Optional in practice, cheap to be correct.
    iim.append(contentsOf: [0x1C, 0x02, 0x00, 0x00, 0x02, 0x00, 0x04])
    for keyword in keywords {
      let bytes = Array(keyword.utf8)
      iim.append(contentsOf: [
        0x1C, 0x02, 0x19, UInt8(bytes.count >> 8), UInt8(bytes.count & 0xFF),
      ])
      iim.append(contentsOf: bytes)
    }

    var resource = Data("Photoshop 3.0\0".utf8)
    resource.append(contentsOf: Array("8BIM".utf8))
    resource.append(contentsOf: [0x04, 0x04])  // IPTC-NAA resource id
    resource.append(contentsOf: [0x00, 0x00])  // empty, even-padded name
    let size = UInt32(iim.count)
    resource.append(contentsOf: [
      UInt8(truncatingIfNeeded: size >> 24), UInt8(truncatingIfNeeded: size >> 16),
      UInt8(truncatingIfNeeded: size >> 8), UInt8(truncatingIfNeeded: size),
    ])
    resource.append(iim)
    if iim.count % 2 == 1 { resource.append(0x00) }

    var segment = Data([0xFF, 0xED])
    let length = resource.count + 2
    segment.append(contentsOf: [UInt8(length >> 8), UInt8(length & 0xFF)])
    segment.append(resource)
    return segment
  }

  /// Run `write`, which is expected to create the entry `name` in
  /// `directory`, and verify it created a *new* entry rather than folding
  /// onto an existing one.
  ///
  /// Byte-wise, because Swift `String` equality is canonical: an NFD name
  /// "already present" as its NFC spelling would look like a replacement
  /// when on Linux it is a second, distinct directory entry.
  private func materialising(
    _ name: String, in directory: String, _ write: () throws -> Void
  ) throws {
    let before = entryNames(in: directory)
    let replacingItself = before.contains(Array(name.utf8))
    try write()
    let after = entryNames(in: directory)
    guard after.count == (replacingItself ? before.count : before.count + 1) else {
      throw FixtureError.destinationFolded(path: directory + "/" + name)
    }
  }

  /// Directory entry names as raw UTF-8, for comparisons the filesystem
  /// would make on bytes.
  private func entryNames(in directory: String) -> [[UInt8]] {
    ((try? fm.contentsOfDirectory(atPath: directory)) ?? []).map { Array($0.utf8) }
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

  /// Plant a zero-byte file with a `.jpg` extension so the read pipeline
  /// accepts it but VIPS fails to open it at write time. Used to exercise
  /// the partial-failure / `BuildReport` path without depending on VIPS
  /// error strings for any other format.
  func plantCorruptPhoto(inAlbum albumRelativePath: String, named name: String) throws {
    let dst = absolutePath(for: albumRelativePath) + "/" + name
    if fm.fileExists(atPath: dst) {
      try fm.removeItem(atPath: dst)
    }
    fm.createFile(atPath: dst, contents: Data())
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
  ///
  /// Uses the path-based enumerator, which already yields paths relative to
  /// the root. The URL-based one reports macOS temp files under
  /// `/private/var/...` while `sourceRoot` is `/var/...`, so stripping a
  /// `sourceRoot` prefix from its output silently matches nothing.
  var allPhotos: [String] {
    let extensions: Set<String> = ["jpg", "jpeg", "JPG", "JPEG"]
    guard let enumerator = fm.enumerator(atPath: sourceRoot) else { return [] }

    var out: [String] = []
    for case let relative as String in enumerator {
      let ext = URL(fileURLWithPath: relative).pathExtension
      guard extensions.contains(ext) else { continue }
      out.append(relative)
    }
    return out.sorted()
  }

  /// Every staged sub-album path, relative to ``sourceRoot``. Mirrors how
  /// Munin counts albums: every directory under the root that ends up as
  /// a gallery album (empty or not). Sorted for determinism.
  var allAlbums: [String] {
    guard let enumerator = fm.enumerator(atPath: sourceRoot) else { return [] }

    var out: [String] = []
    for case let relative as String in enumerator {
      var isDir: ObjCBool = false
      guard fm.fileExists(atPath: sourceRoot + "/" + relative, isDirectory: &isDir), isDir.boolValue
      else { continue }
      out.append(relative)
    }
    return out.sorted()
  }

  /// Every photo filename directly under the given album. Non-recursive —
  /// direct children only, returned without any directory prefix.
  func photosInAlbum(_ albumRelativePath: String) -> [String] {
    let extensions: Set<String> = ["jpg", "jpeg", "JPG", "JPEG"]
    let albumAbsolute = absolutePath(for: albumRelativePath)
    guard let entries = try? fm.contentsOfDirectory(atPath: albumAbsolute) else {
      return []
    }
    return
      entries
      .filter { extensions.contains(URL(fileURLWithPath: $0).pathExtension) }
      .sorted()
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

  // MARK: - Filesystem capabilities

  /// Whether the volume fixtures are staged on keeps two names that differ
  /// only by case (`sample.jpg` / `sample.JPG`) as two files.
  ///
  /// Munin's output-path rules are about bytes, but a test can only
  /// exercise them if the filesystem underneath preserves those bytes.
  /// APFS is case-insensitive by default and normalization-insensitive
  /// always, and `swift-ci.yml` runs the suite on `macos-latest`, so tests
  /// that need either property gate on these and are reported as *skipped*
  /// where it does not hold. Never silently passed: a fixture that folds
  /// two files into one also trips
  /// ``FixtureError/destinationFolded(path:)`` in ``addPhoto``.
  static let filesystemDistinguishesCase: Bool = probeDistinctNames(
    "munin-fsprobe.jpg", "munin-fsprobe.JPG")

  /// Whether the volume keeps NFC and NFD spellings of one name as two
  /// files — what a Linux filesystem does and APFS does not.
  static let filesystemDistinguishesUnicodeNormalization: Bool = probeDistinctNames(
    "munin-fsprobe-H\u{00e5}kon.jpg", "munin-fsprobe-Ha\u{030a}kon.jpg")

  /// Create both names in a fresh temp directory and report whether two
  /// entries resulted.
  private static func probeDistinctNames(_ first: String, _ second: String) -> Bool {
    let fm = FileManager.default
    let dir = fm.temporaryDirectory
      .appendingPathComponent("munin-fsprobe-\(UUID().uuidString)", isDirectory: true)
    guard (try? fm.createDirectory(at: dir, withIntermediateDirectories: true)) != nil else {
      return false
    }
    defer { try? fm.removeItem(at: dir) }
    guard fm.createFile(atPath: dir.path + "/" + first, contents: Data()),
      fm.createFile(atPath: dir.path + "/" + second, contents: Data()),
      let entries = try? fm.contentsOfDirectory(atPath: dir.path)
    else { return false }
    return entries.count == 2
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

  /// A staged file replaced an existing entry rather than creating a new
  /// one, because the filesystem folds names that differ only by case or
  /// by Unicode normalization. The fixture the test asked for does not
  /// exist on this volume, so whatever the test asserts next would be an
  /// assertion about something else.
  case destinationFolded(path: String)

  /// A helper that splices JPEG segments was handed something that is not
  /// a JPEG.
  case notAJPEG(path: String)

  var description: String {
    switch self {
    case .fileMissing(let path):
      return "Fixture file missing: \(path)"
    case .notAJPEG(let path):
      return "Fixture file is not a JPEG (no SOI marker): \(path)"
    case .destinationFolded(let path):
      return """
        Staging '\(path)' replaced an existing file instead of adding one: \
        this filesystem folds names that differ only by case or Unicode \
        normalization (APFS does both), so the fixture cannot be built here. \
        Gate the test on SourceFixture.filesystemDistinguishesCase / \
        .filesystemDistinguishesUnicodeNormalization.
        """
    }
  }
}
