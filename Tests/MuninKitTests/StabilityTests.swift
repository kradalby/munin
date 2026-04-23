import Foundation
import Testing

@testable import MuninKit

/// Guarantees that the gallery build is reproducible across runs.
///
/// These tests encode the core product promise — stable input produces
/// stable output — as machine-enforced assertions. They intentionally do
/// not reach into library internals beyond `GalleryHarness`: if Munin's
/// public behaviour stays the same, the tests stay green.
@Suite(.serialized)
struct StabilityTests {

  // MARK: - Output determinism

  @Test func rebuildingTheSameSourceIsByteDeterministic() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }

    try await harness.build()
    let first = try harness.snapshotOutput()

    // Wipe and rebuild into the same output root so embedded absolute
    // paths (photo URLs, keyword URLs, etc.) are identical across runs.
    // This tests the "same input, same output path → same bytes" invariant
    // that underpins stable incremental rebuilds.
    try FileManager.default.removeItem(atPath: harness.outputRoot)
    try FileManager.default.createDirectory(
      atPath: harness.outputRoot, withIntermediateDirectories: true)

    try await harness.build()
    let second = try harness.snapshotOutput()

    let pathsA = Set(first.leafPaths)
    let pathsB = Set(second.leafPaths)
    #expect(
      pathsA == pathsB,
      "output structure differs: onlyA=\(pathsA.subtracting(pathsB)) onlyB=\(pathsB.subtracting(pathsA))"
    )

    for path in pathsA where path.hasSuffix(".json") {
      guard let a = first.entries[path], let b = second.entries[path] else { continue }
      #expect(a.sha256 == b.sha256, "JSON content differs between runs at \(path)")
    }

    for path in pathsA {
      guard let a = first.entries[path], let b = second.entries[path] else { continue }
      if a.kind == .symlink {
        #expect(
          a.symlinkTarget == b.symlinkTarget,
          "symlink target differs between runs at \(path)")
      }
    }
  }

  // MARK: - JSON surface invariants

  @Test func jsonFilesUseSortedKeys() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.build()

    let snapshot = try harness.snapshotOutput()
    for relPath in snapshot.leafPaths where relPath.hasSuffix(".json") {
      let absolute = harness.outputRoot + "/" + relPath
      let data = try Data(contentsOf: URL(fileURLWithPath: absolute))
      try assertTopLevelKeysSorted(data: data, path: relPath)
    }
  }

  @Test func jsonDoesNotEscapeForwardSlashes() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.build()

    let indexURL = URL(fileURLWithPath: harness.outputGalleryRoot + "/index.json")
    let raw = try String(contentsOf: indexURL, encoding: .utf8)
    #expect(
      !raw.contains("\\/"),
      "index.json still contains escaped forward slashes (\\/)")
    #expect(
      raw.contains("root/Misc/index.json"),
      "expected a normal forward-slash path in index.json")
  }

  // MARK: - Input invariant

  @Test func buildDoesNotModifySourceTree() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }

    let before = try harness.snapshotSource()
    try await harness.build()
    let after = try harness.snapshotSource()

    let diff = before.diff(against: after)
    let summary = """
      added=\(diff.added) removed=\(diff.removed) \
      byteChanged=\(diff.byteChanged) rewrittenIdentical=\(diff.rewrittenIdentical) \
      kindChanged=\(diff.kindChanged)
      """
    #expect(diff.isEmpty, "source tree must not be modified by build: \(summary)")
  }

  // MARK: - Rebuild determinism

  @Test func consecutiveBuildsProduceIdenticalJSON() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }

    try await harness.build()
    let first = try harness.snapshotOutput()
    try await harness.build()
    let second = try harness.snapshotOutput()

    let diff = first.diff(against: second)
    #expect(diff.added == [], "second build added files: \(diff.added)")
    #expect(diff.removed == [], "second build removed files: \(diff.removed)")
    #expect(
      diff.byteChanged == [],
      "second build rewrote JSON with different bytes: \(diff.byteChanged)")
  }

  // MARK: - Helpers

  /// Walk the top-level keys of `data` and assert they appear in
  /// lexicographic order. The check is structural (not byte-level) because
  /// JSON whitespace is implementation-dependent; what we care about is the
  /// ordering invariant that downstream consumers rely on.
  private func assertTopLevelKeysSorted(data: Data, path: String) throws {
    guard (try JSONSerialization.jsonObject(with: data) as? [String: Any]) != nil else {
      // Non-object top-level (arrays etc.) can't violate key ordering.
      return
    }
    let raw = String(data: data, encoding: .utf8) ?? ""
    let orderedKeys = topLevelKeyOrder(of: raw)
    let sorted = orderedKeys.sorted()
    #expect(
      orderedKeys == sorted,
      "\(path) top-level keys out of order: got \(orderedKeys)")
  }

  /// Extract the top-level object keys from a JSON payload in the order
  /// they appear in the byte stream.
  ///
  /// Tracks a small state machine across the tokens that matter:
  /// - `depth`: brace/bracket nesting level (root object starts at depth 1).
  /// - `expectingKey`: `true` immediately after `{` or `,` at the root
  ///   level, flipped back to `false` after `:`.
  ///
  /// Only strings captured while `depth == 1 && expectingKey` are treated
  /// as keys, so embedded string values (including `:` inside URLs and ISO
  /// dates) don't leak into the list.
  private func topLevelKeyOrder(of text: String) -> [String] {
    var depth = 0
    var inString = false
    var escape = false
    var capturing = false
    var expectingKey = false
    var keys: [String] = []
    var current = ""

    for char in text {
      if escape {
        if capturing { current.append(char) }
        escape = false
        continue
      }
      if inString {
        if char == "\\" {
          escape = true
          continue
        }
        if char == "\"" {
          inString = false
          if capturing {
            keys.append(current)
            current = ""
            capturing = false
          }
          continue
        }
        if capturing { current.append(char) }
        continue
      }
      switch char {
      case "{":
        depth += 1
        if depth == 1 { expectingKey = true }
      case "}":
        depth -= 1
      case "[":
        depth += 1
        expectingKey = false
      case "]":
        depth -= 1
      case ",":
        if depth == 1 { expectingKey = true }
      case ":":
        expectingKey = false
      case "\"":
        inString = true
        if depth == 1, expectingKey {
          capturing = true
        }
      default:
        continue
      }
    }
    return keys
  }
}
