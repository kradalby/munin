import Foundation
import SystemPackage

#if canImport(Glibc)
  import Glibc
#elseif canImport(Darwin)
  import Darwin
#endif

/// Thin Swift-level wrappers around the POSIX syscalls Munin needs for
/// filesystem metadata and structure changes. Anything that `FileDescriptor`
/// covers natively (open/read/write/close) lives in `FileIO`; this enum is
/// only the bits swift-system doesn't publicly expose yet.
///
/// Each wrapper throws `MuninError.ioFailure` on failure. A handful return
/// an `Optional` instead — that's the "the file may legitimately not exist"
/// shape, matching the `fileExists` / `attributesOfItem(ifExists:)` patterns
/// the `FileManager` extension used to offer.
enum POSIX {

  // MARK: - Metadata

  /// `lstat(2)`-like metadata snapshot. Dangling symlinks still return a
  /// populated record (they exist as symlinks), matching `isFileOrSymlink`.
  struct FileInfo: Sendable {
    /// Raw mode word from `stat.st_mode`.
    let mode: mode_t
    /// File size in bytes.
    let size: Int64
    /// Modification time, truncated to the resolution `stat` returns.
    let modificationDate: Date

    var isDirectory: Bool { (mode & S_IFMT) == S_IFDIR }
    var isRegularFile: Bool { (mode & S_IFMT) == S_IFREG }
    var isSymlink: Bool { (mode & S_IFMT) == S_IFLNK }
  }

  /// `stat(2)` — follows symlinks. Returns `nil` when the path does not
  /// exist (errno `ENOENT`), throws for every other failure so callers
  /// don't silently miss permission errors.
  static func stat(_ path: FilePath) throws -> FileInfo? {
    try statImpl(path, follow: true)
  }

  /// `lstat(2)` — does not follow the final symlink. Used for "does this
  /// entry exist, even if it's a dangling link" decisions.
  static func lstat(_ path: FilePath) throws -> FileInfo? {
    try statImpl(path, follow: false)
  }

  private static func statImpl(_ path: FilePath, follow: Bool) throws -> FileInfo? {
    var buf = StatBuffer()
    let rc = path.withCString { cPath in
      follow ? system_stat(cPath, &buf) : system_lstat(cPath, &buf)
    }
    if rc != 0 {
      let errno = Errno(rawValue: system_errno)
      if errno == .noSuchFileOrDirectory { return nil }
      throw MuninError.ioFailure(
        operation: follow ? "stat" : "lstat", path: path, errno: errno)
    }
    return FileInfo(
      mode: buf.st_mode,
      size: Int64(buf.st_size),
      modificationDate: modificationDate(from: buf))
  }

  // MARK: - Structure

  /// `mkdir(2)` with intermediate-directory creation. Missing parents are
  /// materialised like `mkdir -p`; an already-existing directory at the
  /// leaf is not an error (matches `FileManager.createDirectory(
  /// withIntermediateDirectories: true)`).
  static func createDirectory(_ path: FilePath, mode: mode_t = 0o755) throws {
    // Build list of ancestors that don't exist yet, leaf first.
    var missing: [FilePath] = []
    var cursor = path
    while true {
      if let info = try lstat(cursor) {
        if info.isDirectory { break }
        throw MuninError.ioFailure(
          operation: "mkdir (parent not a directory)",
          path: cursor,
          errno: .notDirectory)
      }
      missing.append(cursor)
      let parent = cursor.removingLastComponent()
      if parent == cursor || parent.isEmpty { break }
      cursor = parent
    }

    for dir in missing.reversed() {
      let rc = dir.withCString { system_mkdir($0, mode) }
      if rc != 0 {
        let errno = Errno(rawValue: system_errno)
        // Race: somebody else created it between our lstat and mkdir.
        if errno == .fileExists { continue }
        throw MuninError.ioFailure(operation: "mkdir", path: dir, errno: errno)
      }
    }
  }

  /// `unlink(2)`. Removes a file or symlink. Missing targets are treated as
  /// success — the goal state ("no entry at this path") is already true.
  static func unlink(_ path: FilePath) throws {
    let rc = path.withCString { system_unlink($0) }
    if rc != 0 {
      let errno = Errno(rawValue: system_errno)
      if errno == .noSuchFileOrDirectory { return }
      throw MuninError.ioFailure(operation: "unlink", path: path, errno: errno)
    }
  }

  /// `rmdir(2)`. Removes an empty directory. Missing targets are treated as
  /// success. Non-empty directories raise `ENOTEMPTY`.
  static func rmdir(_ path: FilePath) throws {
    let rc = path.withCString { system_rmdir($0) }
    if rc != 0 {
      let errno = Errno(rawValue: system_errno)
      if errno == .noSuchFileOrDirectory { return }
      throw MuninError.ioFailure(operation: "rmdir", path: path, errno: errno)
    }
  }

  /// Remove whatever is at `path`: regular files and symlinks via `unlink`,
  /// directories via `rmdir`. Mirrors `FileManager.removeItem(at:)` for the
  /// non-recursive case Munin actually uses.
  static func removeItem(_ path: FilePath) throws {
    // lstat so we don't follow a symlink to a directory and then try to
    // rmdir the target.
    guard let info = try lstat(path) else { return }
    if info.isDirectory {
      try rmdir(path)
    } else {
      try unlink(path)
    }
  }

  /// Remove `path` recursively, matching `FileManager.removeItem(at:)`
  /// behaviour for directory trees. Files/symlinks `unlink`, directories
  /// are emptied then `rmdir`'d. Used by the clean pass to drop
  /// unreferenced folders that may still contain stale content.
  static func removeItemRecursively(_ path: FilePath) throws {
    guard let info = try lstat(path) else { return }
    if !info.isDirectory {
      try unlink(path)
      return
    }
    for entry in listDirectory(path) {
      try removeItemRecursively(path.appending(entry.name))
    }
    try rmdir(path)
  }

  /// `symlink(2)`. Creates `linkPath` pointing at `target`. `target` is used
  /// verbatim — if the caller wants a relative link (as Munin does for the
  /// symlinked originals), they pass a relative path.
  static func symlink(target: FilePath, linkPath: FilePath) throws {
    let rc = target.withCString { tgt in
      linkPath.withCString { link in
        system_symlink(tgt, link)
      }
    }
    if rc != 0 {
      throw MuninError.ioFailure(
        operation: "symlink", path: linkPath, errno: Errno(rawValue: system_errno))
    }
  }

  /// `rename(2)`. Used by `FileIO.writeAtomic` for the temp → final swap.
  static func rename(from src: FilePath, to dst: FilePath) throws {
    let rc = src.withCString { s in
      dst.withCString { d in
        system_rename(s, d)
      }
    }
    if rc != 0 {
      throw MuninError.ioFailure(
        operation: "rename", path: dst, errno: Errno(rawValue: system_errno))
    }
  }
}

// MARK: - Platform shims

// `stat` exists as both a struct and a function in C, which makes calling
// it from Swift ambiguous. The platform modules expose it unambiguously
// under slightly different names; these shims pick the right one per OS
// and give the rest of `POSIX` a single name to call.

#if canImport(Glibc)
  private typealias StatBuffer = Glibc.stat
  // `stat` is both a type and a function in libc, so `Glibc.stat(p, s)` is
  // ambiguous to Swift. Explicit `@Sendable` wrappers disambiguate and
  // satisfy strict-concurrency's ban on non-Sendable global state.
  @Sendable private func system_stat(
    _ p: UnsafePointer<CChar>, _ s: UnsafeMutablePointer<StatBuffer>
  ) -> Int32 {
    stat(p, s)
  }
  @Sendable private func system_lstat(
    _ p: UnsafePointer<CChar>, _ s: UnsafeMutablePointer<StatBuffer>
  ) -> Int32 {
    lstat(p, s)
  }
  @Sendable private func system_mkdir(_ p: UnsafePointer<CChar>, _ m: mode_t) -> Int32 {
    Glibc.mkdir(p, m)
  }
  @Sendable private func system_unlink(_ p: UnsafePointer<CChar>) -> Int32 { Glibc.unlink(p) }
  @Sendable private func system_rmdir(_ p: UnsafePointer<CChar>) -> Int32 { Glibc.rmdir(p) }
  @Sendable private func system_symlink(
    _ t: UnsafePointer<CChar>, _ l: UnsafePointer<CChar>
  ) -> Int32 {
    Glibc.symlink(t, l)
  }
  @Sendable private func system_rename(
    _ s: UnsafePointer<CChar>, _ d: UnsafePointer<CChar>
  ) -> Int32 {
    Glibc.rename(s, d)
  }
  private var system_errno: Int32 { Glibc.errno }

  private func modificationDate(from buf: StatBuffer) -> Date {
    let sec = TimeInterval(buf.st_mtim.tv_sec)
    let nsec = TimeInterval(buf.st_mtim.tv_nsec) / 1_000_000_000
    return Date(timeIntervalSince1970: sec + nsec)
  }

#elseif canImport(Darwin)
  private typealias StatBuffer = Darwin.stat
  @Sendable private func system_stat(
    _ p: UnsafePointer<CChar>, _ s: UnsafeMutablePointer<StatBuffer>
  ) -> Int32 {
    stat(p, s)
  }
  @Sendable private func system_lstat(
    _ p: UnsafePointer<CChar>, _ s: UnsafeMutablePointer<StatBuffer>
  ) -> Int32 {
    lstat(p, s)
  }
  @Sendable private func system_mkdir(_ p: UnsafePointer<CChar>, _ m: mode_t) -> Int32 {
    Darwin.mkdir(p, m)
  }
  @Sendable private func system_unlink(_ p: UnsafePointer<CChar>) -> Int32 { Darwin.unlink(p) }
  @Sendable private func system_rmdir(_ p: UnsafePointer<CChar>) -> Int32 { Darwin.rmdir(p) }
  @Sendable private func system_symlink(
    _ t: UnsafePointer<CChar>, _ l: UnsafePointer<CChar>
  ) -> Int32 {
    Darwin.symlink(t, l)
  }
  @Sendable private func system_rename(
    _ s: UnsafePointer<CChar>, _ d: UnsafePointer<CChar>
  ) -> Int32 {
    Darwin.rename(s, d)
  }
  private var system_errno: Int32 { Darwin.errno }

  private func modificationDate(from buf: StatBuffer) -> Date {
    let sec = TimeInterval(buf.st_mtimespec.tv_sec)
    let nsec = TimeInterval(buf.st_mtimespec.tv_nsec) / 1_000_000_000
    return Date(timeIntervalSince1970: sec + nsec)
  }
#endif

import Foundation
