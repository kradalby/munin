import SystemPackage

/// One photo that could not be written to disk. A failure here means the
/// photo's on-disk output is incomplete (e.g. VIPS couldn't open the source,
/// the symlink couldn't be recreated, or the metadata JSON write failed),
/// so the caller needs to know which photos to re-run. The `error` preserves
/// the operation + underlying `Errno` / VIPS diagnostic.
public struct PhotoWriteFailure: Sendable, CustomStringConvertible {
  public let photo: String
  public let path: FilePath
  public let error: MuninError

  public var description: String {
    "\(photo) at \(path): \(error)"
  }
}

/// Summary of a build run: how many photos committed their full on-disk
/// output successfully, and which ones failed.
///
/// `Gallery.build` returns this rather than throwing on first failure so a
/// run against tens of thousands of photos can surface partial-failure
/// without losing the work that did succeed. The CLI prints a summary and
/// exits non-zero if `!failures.isEmpty`.
public struct BuildReport: Sendable {
  public var photosWritten: Int
  public var failures: [PhotoWriteFailure]

  public init(photosWritten: Int = 0, failures: [PhotoWriteFailure] = []) {
    self.photosWritten = photosWritten
    self.failures = failures
  }

  public var hasFailures: Bool { !failures.isEmpty }
}
