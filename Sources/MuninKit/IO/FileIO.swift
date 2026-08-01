import Foundation
import SystemPackage

#if canImport(Glibc)
  import Glibc
#elseif canImport(Musl)
  import Musl
#elseif canImport(Darwin)
  import Darwin
#endif

/// Thin convenience layer over `FileDescriptor` for the Data-shaped reads
/// and writes Munin already does. The payoff from Phase B is that these
/// take `FilePath` directly — no `URL(fileURLWithPath:)` bridging at call
/// sites.
///
/// `writeAtomic` writes to a sibling `.tmpXXXXXX` path and renames on
/// success. This is a mild behaviour upgrade over the old
/// `Data.write(to:)` (which defaults to non-atomic): a crash mid-write can
/// no longer leave a half-written JSON file overwriting a valid one.
enum FileIO {

  /// Read the full contents of `path` into memory. Equivalent to
  /// `Data(contentsOf:)` on a regular file but throws `MuninError.ioFailure`
  /// on failure instead of Foundation's generic `NSError`.
  static func read(_ path: FilePath) throws -> Data {
    let fd: FileDescriptor
    do {
      fd = try FileDescriptor.open(path, .readOnly)
    } catch let e as Errno {
      throw MuninError.ioFailure(operation: "open", path: path, errno: e)
    }
    defer { try? fd.close() }

    // Ask stat for a size so we can right-size the buffer in one shot
    // instead of growing as we go.
    let size = (try? POSIX.stat(path))?.size ?? 0
    let capacity = max(Int(size), 4_096)

    var data = Data()
    data.reserveCapacity(capacity)

    var buffer = [UInt8](repeating: 0, count: 64 * 1024)
    while true {
      let n: Int
      do {
        n = try buffer.withUnsafeMutableBytes { ptr in
          try fd.read(into: ptr)
        }
      } catch let e as Errno {
        throw MuninError.ioFailure(operation: "read", path: path, errno: e)
      }
      if n == 0 { break }
      data.append(buffer, count: n)
    }
    return data
  }

  /// Write `data` to `path` via a temp-file-then-rename dance so the final
  /// path is never observed half-written. The parent directory must already
  /// exist — matches Munin's existing pattern where the writer code creates
  /// the containing album directory first.
  static func writeAtomic(_ data: Data, to path: FilePath) throws {
    let tempPath = tempSiblingPath(for: path)

    let fd: FileDescriptor
    do {
      fd = try FileDescriptor.open(
        tempPath,
        .writeOnly,
        options: [.create, .truncate],
        permissions: [.ownerReadWrite, .groupRead, .otherRead])
    } catch let e as Errno {
      throw MuninError.ioFailure(operation: "open (temp)", path: tempPath, errno: e)
    }

    do {
      try data.withUnsafeBytes { buf in
        var remaining = buf
        while !remaining.isEmpty {
          let written: Int
          do {
            written = try fd.write(remaining)
          } catch let e as Errno {
            throw MuninError.ioFailure(operation: "write", path: tempPath, errno: e)
          }
          remaining = UnsafeRawBufferPointer(rebasing: remaining[written...])
        }
      }
      try fd.close()
    } catch {
      try? fd.close()
      try? POSIX.unlink(tempPath)
      throw error
    }

    do {
      try POSIX.rename(from: tempPath, to: path)
    } catch {
      try? POSIX.unlink(tempPath)
      throw error
    }
  }

  /// `path` with a `.tmp<pid>-<randomHex>` suffix on the last component.
  /// Kept in the same directory as the destination so `rename(2)` stays on
  /// one filesystem.
  private static func tempSiblingPath(for path: FilePath) -> FilePath {
    let rand = UInt64.random(in: 0...UInt64.max)
    let suffix = String(format: ".tmp%d-%016llx", pidValue, rand)
    var out = path
    let leaf = out.lastComponent?.string ?? ""
    out.removeLastComponent()
    out.append(leaf + suffix)
    return out
  }

  /// The file's platform imports bring `getpid` into scope on Glibc, Musl and
  /// Darwin alike. The `Int32` annotation is load-bearing: it makes a platform
  /// whose `pid_t` is not `Int32` a compile error rather than a silent `%d`
  /// vararg mismatch above.
  private static var pidValue: Int32 { getpid() }
}
