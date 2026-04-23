import Foundation
import Testing

@testable import MuninKit

/// Proof suite for the incremental-rebuild cache.
///
/// Every scenario asserts a specific ceiling on `ContentHash.callCount`
/// (the number of times a source file was streamed for a SHA-256). The
/// ceilings encode the user-visible performance contract:
///
/// - A no-op rebuild (no source changes, no config changes) must hash
///   **zero** source files.
/// - An mtime-only bump on a source file must hash that file **exactly
///   once** — to prove bytes are unchanged — and never again on
///   subsequent runs.
/// - Replacing source bytes must hash that file **exactly once** per
///   build (the lazy one-shot hasher in `readPhotoFromPath` is shared
///   across fast-path-3 and the slow-path write).
/// - Unrelated files on the same rebuild must still hash zero times.
///
/// Each test pins its assertion numerically against the fixture size so
/// a ceiling regression (e.g. fast-path bypassed, every file re-hashed)
/// fails with an obvious count mismatch rather than a fuzzy timeout.
///
/// A negative-probe test at the end of this file temporarily spoofs an
/// empty prior-photo map and verifies the counts invert — proving the
/// cache is what's doing the work, and that the test suite would catch
/// a regression that removed it.
@Suite(.serialized)
struct RebuildCacheTests {

  // MARK: - Baseline: the counter observes fresh builds correctly

  @Test func firstBuildHashesEverySourceFileOnce() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }

    ContentHash.resetCallCount()
    try await harness.buildAndClean()

    // Misc ships three photos. On a fresh first build there is no prior
    // to consult, so every source file hits the slow path and gets
    // hashed once.
    let hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(
      hashes == 3,
      "expected 3 hashes for fresh Misc build, got \(hashes)")
  }

  // MARK: - No-op rebuild: zero hashes

  @Test func noOpRebuildHashesNothing() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }

    try await harness.buildAndClean()

    try await Task.sleep(nanoseconds: 1_100_000_000)

    ContentHash.resetCallCount()
    try await harness.buildAndClean()

    let hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(
      hashes == 0,
      "no-op rebuild hashed \(hashes) files; the (size, mtime) cache missed for every one"
    )
  }

  @Test func threeNoOpRebuildsHashNothing() async throws {
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }

    try await harness.buildAndClean()

    for run in 1...3 {
      try await Task.sleep(nanoseconds: 1_100_000_000)
      ContentHash.resetCallCount()
      try await harness.buildAndClean()
      let hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
      #expect(
        hashes == 0,
        "rebuild #\(run) of the full example gallery hashed \(hashes) files")
    }
  }

  // MARK: - Mtime-only drift: hash once, then cached

  @Test func mtimeDriftHashesEachAffectedFileExactlyOnceAndThenCaches()
    async throws
  {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }

    try await harness.buildAndClean()
    try await Task.sleep(nanoseconds: 1_100_000_000)

    // Touch all three source files' mtimes without changing bytes.
    for name in ["portrait_mm.jpeg", "20180510-171752-IMG_7165.jpg", "test_special_chars.jpg"] {
      try fixture.touchPhoto(inAlbum: "Misc", named: name)
    }

    // Build after mtime drift. The cache's (size, mtime) check misses
    // for each of the three files, so fast-path-3 hashes each once. No
    // second hash happens in the slow path because hashing matches
    // prior and the fast-path-3 reuse short-circuits before the slow
    // path's VIPS/EXIF/hash call.
    ContentHash.resetCallCount()
    try await harness.buildAndClean()
    let driftHashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(
      driftHashes == 3,
      "mtime-drift build hashed \(driftHashes) files; expected exactly 3")

    // Next build: prior was updated with the new mtimes, so the
    // (size, mtime) check hits for every photo and zero hashing
    // happens. This is the post-drift steady state the user of a
    // 45k-photo gallery cares about.
    try await Task.sleep(nanoseconds: 1_100_000_000)
    ContentHash.resetCallCount()
    try await harness.buildAndClean()
    let postDriftHashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(
      postDriftHashes == 0,
      "post-drift rebuild still hashed \(postDriftHashes) files; cache was not updated"
    )
  }

  @Test func mtimeDriftDoesNotReencodeImages() async throws {
    // Companion to the hash-count assertion: a touch-only drift must
    // also leave the scaled image outputs alone.
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }

    try await harness.buildAndClean()
    let before = try harness.snapshotOutput()

    try await Task.sleep(nanoseconds: 1_100_000_000)
    for name in ["portrait_mm.jpeg", "20180510-171752-IMG_7165.jpg", "test_special_chars.jpg"] {
      try fixture.touchPhoto(inAlbum: "Misc", named: name)
    }
    try await harness.buildAndClean()
    let after = try harness.snapshotOutput()

    let diff = before.diff(against: after)
    let scaledTouched = (diff.byteChanged + diff.rewrittenIdentical).filter {
      ($0.hasSuffix(".jpg") || $0.hasSuffix(".jpeg"))
        && $0.contains("_") && !$0.hasSuffix("_original.jpg") && !$0.hasSuffix("_original.jpeg")
    }
    #expect(
      scaledTouched == [],
      "mtime drift re-encoded \(scaledTouched.count) scaled image(s): \(scaledTouched)")
  }

  // MARK: - Byte change: hash only the affected file

  @Test func replacingOnePhotosBytesHashesOnlyThatFile() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc", "2024"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }

    try await harness.buildAndClean()
    try await Task.sleep(nanoseconds: 1_100_000_000)

    try fixture.replacePhoto(
      inAlbum: "Misc",
      named: "portrait_mm.jpeg",
      withSourceFile: fixture.originPhoto(
        "2024/2024-06-21_Håkon_har_nytt_kamera/_DSF0055.JPG")
    )

    ContentHash.resetCallCount()
    try await harness.buildAndClean()

    // Only the replaced photo missed the cache: its (size, mtime)
    // differ from prior, and its hash differs too. The lazy hasher
    // folds fast-path-3 and the slow-path hash into a single call,
    // so the count is exactly one.
    let hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(
      hashes == 1,
      "byte-replacement build hashed \(hashes) files; expected exactly 1")
  }

  // MARK: - Negative probe: cache disabled → every file is hashed

  /// Construct an input-read path that's been starved of its prior map,
  /// run a build on already-populated output, and verify every source
  /// file gets re-hashed. This proves the cache is what avoids the
  /// hashing — not some other property of the pipeline — and that the
  /// tests above would fail loudly if someone accidentally dropped the
  /// `priorPhotos` plumbing.
  @Test func disablingPriorMapForcesHashOfEverySource() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }

    try await harness.buildAndClean()
    try await Task.sleep(nanoseconds: 1_100_000_000)

    // Re-read input with an empty prior map, simulating a bug that
    // forgot to thread the map through. Every file should fall through
    // to the slow path and hash.
    ContentHash.resetCallCount()
    _ = try await readStateFromInputDirectory(
      ctx: harness.ctx,
      atPath: harness.sourceRoot,
      outPath: harness.outputRoot,
      name: "root",
      parents: [],
      priorPhotos: [:]
    )
    let hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(
      hashes == 3,
      "with an empty prior map the read pipeline must hash all 3 files, got \(hashes)"
    )
  }
}
