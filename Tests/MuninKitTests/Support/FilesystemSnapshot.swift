import Crypto
import Foundation

/// A recursive snapshot of a directory tree, used to assert whether
/// incremental rebuilds actually rebuild only what is supposed to change.
///
/// The snapshot records enough per-entry information to distinguish the
/// three things tests care about:
///
/// - **existence** — added / removed files or symlinks
/// - **content** — bytes changed (compared via SHA-256)
/// - **freshness** — file was rewritten to identical bytes (mtime changed
///   but content hash unchanged)
///
/// Directories themselves are recorded for structural integrity but do not
/// participate in byte- or mtime-diffs.
///
/// Paths are stored relative to the root passed to ``capture(at:)`` so
/// snapshots taken from different absolute roots (e.g. two separate temp
/// build outputs) compare cleanly.
struct FilesystemSnapshot: Equatable {

  /// The kind of filesystem object at a given path.
  enum Kind: String, Equatable {
    case file
    case symlink
    case directory
  }

  /// One recorded entry. For directories, ``size`` is zero and ``sha256``
  /// and ``symlinkTarget`` are `nil`.
  struct Entry: Equatable {
    let kind: Kind
    let size: Int
    let sha256: String?
    let symlinkTarget: String?
    let mtime: Date?
  }

  /// Relative path → entry. Relative paths are POSIX-style with forward
  /// slashes regardless of host OS.
  let entries: [String: Entry]

  /// Walk `root` depth-first and capture every entry below it.
  ///
  /// Hidden dotfiles (names starting with `.`) are intentionally included
  /// because Munin doesn't emit any, and their presence would indicate the
  /// test has leaked state.
  static func capture(at root: String) throws -> FilesystemSnapshot {
    let fm = FileManager.default
    var result: [String: Entry] = [:]

    // Existence of `root` itself is required; callers should ensure the
    // directory has been created before snapshotting.
    var isDir: ObjCBool = false
    guard fm.fileExists(atPath: root, isDirectory: &isDir), isDir.boolValue else {
      throw SnapshotError.rootMissing(path: root)
    }

    try walk(relative: "", absolute: root, fm: fm, into: &result)
    return FilesystemSnapshot(entries: result)
  }

  private static func walk(
    relative: String, absolute: String, fm: FileManager, into result: inout [String: Entry]
  ) throws {
    // Use contentsOfDirectory (not enumerator) so we can distinguish
    // symlinks from files/directories via lstat-equivalent attribute reads.
    let contents: [String]
    do {
      contents = try fm.contentsOfDirectory(atPath: absolute).sorted()
    } catch {
      throw SnapshotError.directoryUnreadable(path: absolute, underlying: "\(error)")
    }

    for name in contents {
      let childRelative = relative.isEmpty ? name : relative + "/" + name
      let childAbsolute = absolute + "/" + name

      // attributesOfItem follows symlinks; we want destinationOfSymbolicLink
      // behaviour instead, so check symlink status first.
      let linkAttrs: [FileAttributeKey: Any]
      do {
        linkAttrs = try fm.attributesOfItem(atPath: childAbsolute)
      } catch {
        throw SnapshotError.entryUnreadable(path: childAbsolute, underlying: "\(error)")
      }

      let type = linkAttrs[.type] as? FileAttributeType
      let mtime = linkAttrs[.modificationDate] as? Date

      if type == .typeSymbolicLink {
        let target = (try? fm.destinationOfSymbolicLink(atPath: childAbsolute)) ?? ""
        result[childRelative] = Entry(
          kind: .symlink, size: 0, sha256: nil, symlinkTarget: target, mtime: mtime)
        continue
      }

      if type == .typeDirectory {
        result[childRelative] = Entry(
          kind: .directory, size: 0, sha256: nil, symlinkTarget: nil, mtime: mtime)
        try walk(relative: childRelative, absolute: childAbsolute, fm: fm, into: &result)
        continue
      }

      if type == .typeRegular {
        let size = (linkAttrs[.size] as? NSNumber)?.intValue ?? 0
        let hash = try sha256Hex(ofFileAt: childAbsolute)
        result[childRelative] = Entry(
          kind: .file, size: size, sha256: hash, symlinkTarget: nil, mtime: mtime)
        continue
      }

      // Unknown or unsupported (sockets, pipes, devices). Tests should not
      // encounter these under Munin's output tree; record them as files
      // with no hash so they'd still show as "present" in diffs.
      result[childRelative] = Entry(
        kind: .file, size: 0, sha256: nil, symlinkTarget: nil, mtime: mtime)
    }
  }

  /// Streaming SHA-256 of the file at `path`. Memory-safe for large images
  /// — never materialises more than a 64 KiB chunk.
  private static func sha256Hex(ofFileAt path: String) throws -> String {
    let url = URL(fileURLWithPath: path)
    let handle: FileHandle
    do {
      handle = try FileHandle(forReadingFrom: url)
    } catch {
      throw SnapshotError.entryUnreadable(path: path, underlying: "\(error)")
    }
    defer { try? handle.close() }

    var hasher = SHA256()
    while true {
      // readData(ofLength:) is deprecated on newer Foundations but remains
      // the portable lowest-common-denominator across Linux + Darwin.
      let chunk = handle.readData(ofLength: 64 * 1024)
      if chunk.isEmpty { break }
      hasher.update(data: chunk)
    }
    let digest = hasher.finalize()
    return digest.map { String(format: "%02x", $0) }.joined()
  }
}

extension FilesystemSnapshot {

  /// Structural diff between two snapshots: what was added, removed,
  /// rewritten with new content, or rewritten with identical content.
  struct Diff: Equatable {
    /// Paths present in `after` but not in `before`.
    var added: [String] = []
    /// Paths present in `before` but not in `after`.
    var removed: [String] = []
    /// File or symlink paths whose bytes (or target) differ.
    var byteChanged: [String] = []
    /// File paths whose content is unchanged but mtime moved (i.e. the file
    /// was rewritten with identical bytes — a sign of a wasteful rebuild).
    var rewrittenIdentical: [String] = []
    /// Entries whose kind changed (e.g. file → symlink).
    var kindChanged: [String] = []

    var isEmpty: Bool {
      added.isEmpty && removed.isEmpty && byteChanged.isEmpty
        && rewrittenIdentical.isEmpty && kindChanged.isEmpty
    }
  }

  /// Compute `self → other`. Directory entries only contribute to `added` /
  /// `removed` / `kindChanged`; their mtime changes are suppressed because
  /// any modification under a directory legitimately bumps its mtime.
  func diff(against other: FilesystemSnapshot) -> Diff {
    var out = Diff()
    let keysBefore = Set(entries.keys)
    let keysAfter = Set(other.entries.keys)

    out.added = keysAfter.subtracting(keysBefore).sorted()
    out.removed = keysBefore.subtracting(keysAfter).sorted()

    for key in keysBefore.intersection(keysAfter).sorted() {
      guard let lhs = entries[key], let rhs = other.entries[key] else { continue }

      if lhs.kind != rhs.kind {
        out.kindChanged.append(key)
        continue
      }

      switch lhs.kind {
      case .directory:
        // Directories don't carry byte/mtime signal we care about.
        continue
      case .symlink:
        if lhs.symlinkTarget != rhs.symlinkTarget {
          out.byteChanged.append(key)
        }
      case .file:
        if lhs.sha256 != rhs.sha256 {
          out.byteChanged.append(key)
        } else if lhs.mtime != rhs.mtime {
          out.rewrittenIdentical.append(key)
        }
      }
    }
    return out
  }

  /// All file-or-symlink paths in the snapshot, sorted. Handy for asserting
  /// against a golden manifest.
  var leafPaths: [String] {
    entries.filter { $0.value.kind != .directory }.keys.sorted()
  }
}

enum SnapshotError: Error, CustomStringConvertible {
  case rootMissing(path: String)
  case directoryUnreadable(path: String, underlying: String)
  case entryUnreadable(path: String, underlying: String)

  var description: String {
    switch self {
    case .rootMissing(let path):
      return "Snapshot root missing or not a directory: \(path)"
    case .directoryUnreadable(let path, let underlying):
      return "Snapshot could not read directory \(path): \(underlying)"
    case .entryUnreadable(let path, let underlying):
      return "Snapshot could not read entry \(path): \(underlying)"
    }
  }
}
