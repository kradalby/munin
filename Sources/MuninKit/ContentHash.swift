import Crypto
import Foundation

/// Content-hashing helpers used to decide whether a source photo's bytes
/// have changed between builds.
///
/// Hashes are SHA-256 (64-hex-char strings). SHA-256 is chosen over SHA-1
/// to avoid collision concerns entirely; it costs more CPU but the I/O
/// cost of the read dominates, and libvips will re-read the same files
/// anyway during encoding.
///
/// To keep rebuild cost bounded on large galleries (tens of thousands of
/// photos), the read pipeline avoids calling ``sha256(ofFileAt:)`` when
/// a previously-recorded `(fileSize, modifiedDate)` still matches what's
/// on disk. That lookup happens in `Photo+Read.swift`; see the per-photo
/// cache path there.
enum ContentHash {

  /// Streaming SHA-256 of the file at `path`. Returns the lowercase hex
  /// digest.
  ///
  /// Reads in 64 KiB chunks so hashing a 50 MB RAW file never materialises
  /// more than that in memory.
  ///
  /// - Throws: `MuninError.imageOperationFailed` wrapping any underlying
  ///   I/O failure (file missing, permission denied, etc.).
  static func sha256(ofFileAt path: String) throws -> String {
    Counter.shared.record(path)
    let url = URL(fileURLWithPath: path)
    let handle: FileHandle
    do {
      handle = try FileHandle(forReadingFrom: url)
    } catch {
      throw MuninError.imageOperationFailed(
        path: path, operation: "sha256", underlying: "\(error)")
    }
    defer { try? handle.close() }

    var hasher = SHA256()
    while true {
      let chunk = handle.readData(ofLength: 64 * 1024)
      if chunk.isEmpty { break }
      hasher.update(data: chunk)
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }

  /// Number of times ``sha256(ofFileAt:)`` has been invoked during the
  /// lifetime of the process, for tests that assert the read pipeline
  /// isn't hashing files it shouldn't.
  ///
  /// Thread-safe.
  static var callCount: Int {
    Counter.shared.count(matching: nil)
  }

  /// Number of ``sha256(ofFileAt:)`` invocations whose input path starts
  /// with `prefix`. Used by tests to scope assertions to a particular
  /// fixture's tempdir and avoid cross-test counter contamination when
  /// multiple suites run in parallel.
  static func callCount(forPathsUnder prefix: String) -> Int {
    Counter.shared.count(matching: prefix)
  }

  /// Clear the path log. Tests call this before the interesting build so
  /// counts cover only that build.
  static func resetCallCount() {
    Counter.shared.reset()
  }
}

/// Process-global log of paths passed to ``ContentHash.sha256(ofFileAt:)``.
/// Path-scoped rather than a bare integer so tests running in parallel
/// suites don't contaminate each other's counts — each suite filters to
/// its own tempdir.
private final class Counter: @unchecked Sendable {
  static let shared = Counter()
  private let lock = NSLock()
  private var log: [String] = []

  func record(_ path: String) {
    lock.lock()
    log.append(path)
    lock.unlock()
  }

  func count(matching prefix: String?) -> Int {
    lock.lock()
    defer { lock.unlock() }
    guard let prefix else { return log.count }
    return log.reduce(0) { $0 + ($1.hasPrefix(prefix) ? 1 : 0) }
  }

  func reset() {
    lock.lock()
    log.removeAll(keepingCapacity: true)
    lock.unlock()
  }
}
