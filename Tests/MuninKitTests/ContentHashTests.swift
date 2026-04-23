import Foundation
import Testing

@testable import MuninKit

@Suite
struct ContentHashTests {

  @Test func sha256IsDeterministic() throws {
    let root = try makeScratchDir()
    defer { try? FileManager.default.removeItem(atPath: root) }

    let path = root + "/payload.bin"
    try Data("hello world".utf8).write(to: URL(fileURLWithPath: path))

    let first = try ContentHash.sha256(ofFileAt: path)
    let second = try ContentHash.sha256(ofFileAt: path)
    #expect(first == second)
    // Well-known SHA-256 of "hello world" for a sanity cross-check.
    #expect(first == "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9")
  }

  @Test func sha256ChangesWhenBytesChange() throws {
    let root = try makeScratchDir()
    defer { try? FileManager.default.removeItem(atPath: root) }

    let path = root + "/payload.bin"
    try Data("aaa".utf8).write(to: URL(fileURLWithPath: path))
    let before = try ContentHash.sha256(ofFileAt: path)

    try Data("aaab".utf8).write(to: URL(fileURLWithPath: path))
    let after = try ContentHash.sha256(ofFileAt: path)

    #expect(before != after)
  }

  @Test func sha256IsIndependentOfMtime() throws {
    let root = try makeScratchDir()
    defer { try? FileManager.default.removeItem(atPath: root) }

    let path = root + "/payload.bin"
    try Data("stable".utf8).write(to: URL(fileURLWithPath: path))
    let before = try ContentHash.sha256(ofFileAt: path)

    // Bump mtime without touching bytes.
    let future = Date().addingTimeInterval(300)
    try FileManager.default.setAttributes(
      [.modificationDate: future], ofItemAtPath: path)

    let after = try ContentHash.sha256(ofFileAt: path)
    #expect(before == after)
  }

  @Test func sha256StreamsLargeFilesWithoutFaulting() throws {
    // Hashes a ~5 MiB file to exercise the chunked read path. 5 MiB easily
    // exceeds the 64 KiB internal buffer so we know streaming is actually
    // happening.
    let root = try makeScratchDir()
    defer { try? FileManager.default.removeItem(atPath: root) }

    let path = root + "/big.bin"
    // Deterministic: repeat a short pattern.
    let pattern = Data(repeating: 0xAB, count: 1024)
    var buffer = Data(capacity: 5 * 1024 * 1024)
    for _ in 0..<(5 * 1024) { buffer.append(pattern) }
    try buffer.write(to: URL(fileURLWithPath: path))

    let hash = try ContentHash.sha256(ofFileAt: path)
    #expect(hash.count == 64)
    // Recompute to confirm stability at size.
    let again = try ContentHash.sha256(ofFileAt: path)
    #expect(hash == again)
  }

  @Test func sha256ThrowsOnMissingFile() {
    do {
      _ = try ContentHash.sha256(ofFileAt: "/nonexistent/path/\(UUID().uuidString)")
      Issue.record("expected a throw for a missing file")
    } catch {
      // Any error is acceptable — the contract is "does not silently
      // succeed for a missing file".
    }
  }

  private func makeScratchDir() throws -> String {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("munin-hash-\(UUID().uuidString)").path
    try FileManager.default.createDirectory(
      atPath: dir, withIntermediateDirectories: true)
    return dir
  }
}
