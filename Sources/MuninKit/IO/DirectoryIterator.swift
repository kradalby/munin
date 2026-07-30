import Foundation
import SystemPackage

#if canImport(Glibc)
  import Glibc
#elseif canImport(Darwin)
  import Darwin
#endif

/// A single entry from a directory listing.
struct DirectoryEntry: Sendable {
  /// Last path component — e.g. `"photo.jpg"`, never the full path.
  let name: String

  /// `d_type` from `readdir(3)`. Not all filesystems populate this (NFS,
  /// some Linux FUSE mounts return `DT_UNKNOWN`); callers that must know
  /// should `lstat` the joined path.
  let kind: Kind

  enum Kind: Sendable {
    case file
    case directory
    case symlink
    case unknown
  }
}

/// Iterates the entries in a directory via `opendir(3)` / `readdir(3)` /
/// `closedir(3)`. Acts as the direct replacement for the
/// `FileManager.contentsOfDirectory(atPath:)` family — raw entries come out
/// and Munin filters them (by extension, hidden-file rules, etc.) at the
/// call site the way the old `FileManager.swift` extension methods did.
///
/// This is a `class` so that `deinit` can close the directory handle
/// deterministically; `DIR*` is not `Sendable`, so the class is
/// `@unchecked Sendable` by virtue of never being shared between tasks.
/// Callers are expected to iterate and drop the stream synchronously.
final class DirectoryStream: Sequence, IteratorProtocol {
  typealias Element = DirectoryEntry

  private let path: FilePath
  private var handle: DirHandle?

  init(_ path: FilePath) throws {
    self.path = path
    let h = path.withCString { opendir($0) }
    guard let h else {
      throw MuninError.ioFailure(
        operation: "opendir", path: path, errno: Errno(rawValue: currentErrno))
    }
    self.handle = h
  }

  deinit {
    if let handle {
      closedir(handle)
    }
  }

  func next() -> DirectoryEntry? {
    guard let handle else { return nil }
    while true {
      // `readdir` returns `nil` both for end-of-stream and for errors.
      // errno must be cleared beforehand to tell them apart.
      setErrno(0)
      guard let entryPtr = readdir(handle) else {
        // Swallow read errors silently — mirrors the old FileManager
        // extension's behaviour of just returning what it could find.
        return nil
      }
      let name = nameString(from: entryPtr)
      if name == "." || name == ".." { continue }
      return DirectoryEntry(name: name, kind: kind(from: entryPtr))
    }
  }
}

// MARK: - Directory helpers

/// Synchronous snapshot of a directory's entries. Sorted alphabetically to
/// match `FileManager.contentsOfDirectory(atPath:)`'s stable-ish output,
/// which the rest of Munin treats as de-facto sorted.
///
/// Missing directories return `[]` rather than throwing — mirrors the old
/// `FileManager` extension methods which swallowed their errors and
/// returned an empty list, so callers never have to special-case an album
/// folder that hasn't been created yet.
func listDirectory(_ path: FilePath) -> [DirectoryEntry] {
  var entries: [DirectoryEntry] = []
  do {
    let stream = try DirectoryStream(path)
    for entry in stream {
      entries.append(entry)
    }
  } catch {
    return []
  }
  entries.sort { $0.name < $1.name }
  return entries
}

/// Names of sub-directories directly under `path`. Filters by `lstat`ing
/// any `DT_UNKNOWN` entries so filesystems that don't populate `d_type`
/// (some FUSE mounts, NFS) still get correct results.
func directoryNames(under path: FilePath) -> [String] {
  listDirectory(path).compactMap { entry in
    switch entry.kind {
    case .directory: return entry.name
    case .unknown:
      let child = path.appending(entry.name)
      let info = try? POSIX.lstat(child)
      return info?.isDirectory == true ? entry.name : nil
    default: return nil
    }
  }
}

/// Names of files and symlinks directly under `path`. Dangling symlinks
/// are included — `lstat` reports the link itself, not its target.
func fileOrSymlinkNames(under path: FilePath) -> [String] {
  listDirectory(path).compactMap { entry in
    switch entry.kind {
    case .file, .symlink: return entry.name
    case .unknown:
      let child = path.appending(entry.name)
      guard let info = try? POSIX.lstat(child) else { return nil }
      return (info.isRegularFile || info.isSymlink) ? entry.name : nil
    case .directory: return nil
    }
  }
}

/// Regular-file-or-symlink predicate via `lstat`. Used by the clean-up
/// pass to decide whether a would-be entry of a photo's expected-files
/// list is present on disk, including dangling symlinks.
func isFileOrSymlink(at path: FilePath) -> Bool {
  guard let info = try? POSIX.lstat(path) else { return false }
  return info.isRegularFile || info.isSymlink
}

// MARK: - Platform shims

#if canImport(Glibc)
  /// glibc's `DIR` is fully opaque, so `opendir` imports as `OpaquePointer`;
  /// Darwin exposes the struct and returns `UnsafeMutablePointer<DIR>`.
  private typealias DirHandle = OpaquePointer

  private var currentErrno: Int32 { Glibc.errno }
  private func setErrno(_ v: Int32) { Glibc.errno = v }

  private func nameString(from ptr: UnsafeMutablePointer<dirent>) -> String {
    withUnsafePointer(to: &ptr.pointee.d_name) { tuplePtr in
      tuplePtr.withMemoryRebound(to: CChar.self, capacity: 1) { cPtr in
        String(cString: cPtr)
      }
    }
  }

  private func kind(from ptr: UnsafeMutablePointer<dirent>) -> DirectoryEntry.Kind {
    switch Int(ptr.pointee.d_type) {
    case DT_REG: return .file
    case DT_DIR: return .directory
    case DT_LNK: return .symlink
    default: return .unknown
    }
  }

#elseif canImport(Darwin)
  private typealias DirHandle = UnsafeMutablePointer<DIR>

  private var currentErrno: Int32 { Darwin.errno }
  private func setErrno(_ v: Int32) { Darwin.errno = v }

  private func nameString(from ptr: UnsafeMutablePointer<dirent>) -> String {
    let nameLen = Int(ptr.pointee.d_namlen)
    return withUnsafePointer(to: &ptr.pointee.d_name) { tuplePtr in
      tuplePtr.withMemoryRebound(to: CChar.self, capacity: nameLen) { cPtr in
        String(
          decoding: UnsafeBufferPointer(
            start: UnsafePointer<UInt8>(OpaquePointer(cPtr)), count: nameLen),
          as: UTF8.self)
      }
    }
  }

  // Darwin's DT_* are Int32, glibc's are Int.
  private func kind(from ptr: UnsafeMutablePointer<dirent>) -> DirectoryEntry.Kind {
    switch Int32(ptr.pointee.d_type) {
    case DT_REG: return .file
    case DT_DIR: return .directory
    case DT_LNK: return .symlink
    default: return .unknown
    }
  }
#endif
