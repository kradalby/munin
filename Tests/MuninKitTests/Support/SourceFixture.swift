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

enum FixtureError: Error, CustomStringConvertible {
  case fileMissing(path: String)

  var description: String {
    switch self {
    case .fileMissing(let path):
      return "Fixture file missing: \(path)"
    }
  }
}
