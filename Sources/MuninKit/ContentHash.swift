import Crypto
import Foundation

/// Content-hashing helpers used to decide whether a source photo's bytes
/// have changed between builds.
///
/// Hashes are SHA-256 (64-hex-char strings). SHA-256 is chosen over SHA-1
/// to avoid collision concerns entirely; it costs more CPU but the I/O
/// cost of the read dominates, and libvips will re-read the same files
/// anyway during encoding. If a future optimisation wants to cache hashes
/// keyed by `(path, size, mtime)` the public API here stays stable.
enum ContentHash {

  /// Streaming SHA-256 of the file at `path`. Returns the lowercase hex
  /// digest.
  ///
  /// Reads in 64 KiB chunks so hashing a 50 MB RAW file never materialises
  /// more than that in memory.
  ///
  /// - Throws: `MuninError.metadataError` wrapping any underlying I/O
  ///   failure (file missing, permission denied, etc.).
  static func sha256(ofFileAt path: String) throws -> String {
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
}
