import Foundation
import Testing

@testable import MuninKit

/// End-to-end tests for the incremental-rebuild contract. For every
/// scenario — add a photo, touch an mtime, replace bytes, rename an
/// album, and so on — the test constructs a known source tree, runs a
/// baseline build, mutates the source, rebuilds, and then snapshot-diffs
/// the output directory to assert *exactly* which files changed and
/// which were left alone.
///
/// The central invariant these tests lock:
///
/// - Scaled images are a function of source bytes alone; they are
///   rewritten iff the source bytes changed.
/// - JSON metadata is always rewritten on a rebuild (existing
///   behaviour), but for an unchanged source the rewrites produce
///   byte-identical payloads thanks to `MuninJSON`'s canonical encoder
///   (locked in `StabilityTests`).
///
/// Each test sleeps briefly between the baseline build and the
/// incremental rebuild so mtime differences are detectable even on
/// filesystems with low-resolution timestamps (e.g. HFS+'s 1-second
/// granularity). Tests that only need to observe content drift ignore
/// the rewrittenIdentical set.
@Suite(.serialized)
struct IncrementalRebuildTests {

  // MARK: - Baseline: no-op rebuild

  @Test func rebuildWithoutAnyChangeDoesNotReencodeImages() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let before = try harness.snapshotOutput()

    try await sleepPastMtimeResolution()
    try await harness.buildAndClean()
    let after = try harness.snapshotOutput()

    let diff = before.diff(against: after)

    #expect(diff.added == [], "rebuild added files: \(diff.added)")
    #expect(diff.removed == [], "rebuild removed files: \(diff.removed)")
    #expect(diff.byteChanged == [], "rebuild changed bytes: \(diff.byteChanged)")

    let scaledWritten = scaledImagePaths(in: diff.rewrittenIdentical)
    #expect(
      scaledWritten == [],
      "scaled images were rewritten with identical bytes (wasted work): \(scaledWritten)")
  }

  /// Full-scale proof that three back-to-back rebuilds of the entire
  /// example gallery never re-encode a single scaled image.
  ///
  /// This is the test that directly contradicts "incremental doesn't work
  /// in practice": if any of the 104 photos had been re-encoded on any of
  /// the three subsequent rebuilds, the corresponding path would appear
  /// in `rewrittenIdentical` (or `byteChanged`) at least once and the
  /// assertion would fail with the offending path.
  @Test func threeFullGalleryRebuildsNeverReencodeAnyImage() async throws {
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let baseline = try harness.snapshotOutput()

    // Sanity: the first build actually wrote enough scaled images to make
    // this test meaningful.
    let initialScaled = scaledImagePaths(in: Array(baseline.entries.keys))
    #expect(
      initialScaled.count >= 100,
      "expected >=100 scaled images from full example gallery, got \(initialScaled.count)")

    var previous = baseline
    for run in 1...3 {
      try await sleepPastMtimeResolution()
      try await harness.buildAndClean()
      let current = try harness.snapshotOutput()
      let diff = previous.diff(against: current)

      let scaledTouched = scaledImagePaths(
        in: diff.byteChanged + diff.rewrittenIdentical)
      #expect(
        scaledTouched == [],
        "run #\(run) of an idempotent rebuild touched \(scaledTouched.count) scaled image(s): \(scaledTouched.prefix(5))"
      )
      #expect(
        diff.added == [],
        "run #\(run) added files: \(diff.added.prefix(5))")
      #expect(
        diff.removed == [],
        "run #\(run) removed files: \(diff.removed.prefix(5))")
      previous = current
    }
  }

  /// Regression guard against the pre-sourceHash behaviour. Bumps every
  /// source file's mtime between builds and verifies that the incremental
  /// pipeline still considers the gallery unchanged.
  ///
  /// Under the old `modifiedDate`-in-equality semantics this test would
  /// re-encode every photo; under content-hash equality it must be a
  /// no-op at the image level.
  @Test func touchingEverySourceFileMtimeDoesNotReencodeAnyImage() async throws {
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let before = try harness.snapshotOutput()

    try await sleepPastMtimeResolution()

    // Touch every source photo — the moral equivalent of the user
    // running `rsync` without `-t`, restoring from a backup that
    // doesn't preserve mtimes, or running `touch -r nowfile *.jpg`.
    try touchEverySourcePhoto(under: fixture.sourceRoot)

    try await harness.buildAndClean()
    let after = try harness.snapshotOutput()

    let diff = before.diff(against: after)
    let scaledTouched = scaledImagePaths(
      in: diff.byteChanged + diff.rewrittenIdentical)
    #expect(
      scaledTouched == [],
      "mtime-only drift on every source file re-encoded \(scaledTouched.count) scaled image(s): \(scaledTouched.prefix(5))"
    )
  }

  // MARK: - Mtime-only bump on a single photo

  @Test func touchingSourceMtimeDoesNotReencodeImage() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let before = try harness.snapshotOutput()

    try await sleepPastMtimeResolution()
    try fixture.touchPhoto(inAlbum: "Misc", named: "portrait_mm.jpeg")
    try await harness.buildAndClean()
    let after = try harness.snapshotOutput()

    let diff = before.diff(against: after)

    // Touching mtime changes Photo.modifiedDate, which is serialised into
    // the JSON. That is a small, intentional byte change — but the
    // expensive image work must not happen.
    #expect(diff.added == [])
    #expect(diff.removed == [])

    let scaledChanged = scaledImagePaths(in: diff.byteChanged + diff.rewrittenIdentical)
    #expect(
      scaledChanged == [],
      "touching mtime must not rewrite any scaled image: \(scaledChanged)")

    // The touched photo's JSON records the new mtime so it's legitimately
    // byte-changed. No other photo JSON should byte-change.
    let touchedJsonChanges = diff.byteChanged.filter {
      $0.hasSuffix("portrait_mm.json")
    }
    #expect(
      !touchedJsonChanges.isEmpty,
      "touched photo's JSON must reflect the new mtime")
  }

  // MARK: - Byte replacement on a single photo

  @Test func replacingSourceBytesReencodesOnlyThatPhoto() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc", "2024"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let before = try harness.snapshotOutput()

    try await sleepPastMtimeResolution()
    // Overwrite portrait_mm.jpeg with a different source (a JPEG from
    // the 2024 album), so SHA-256 changes. VIPS should re-encode.
    try fixture.replacePhoto(
      inAlbum: "Misc",
      named: "portrait_mm.jpeg",
      withSourceFile: fixture.originPhoto(
        "2024/2024-06-21_Håkon_har_nytt_kamera/_DSF0055.JPG")
    )
    try await harness.buildAndClean()
    let after = try harness.snapshotOutput()

    let diff = before.diff(against: after)
    let bytePaths = Set(diff.byteChanged)

    // The replaced photo's scaled outputs must have changed.
    #expect(bytePaths.contains("root/Misc/portrait_mm_180.jpeg"))
    #expect(bytePaths.contains("root/Misc/portrait_mm_340.jpeg"))

    // No other scaled image should have been re-encoded (byteChanged).
    let otherReencodes = diff.byteChanged.filter {
      ($0.hasSuffix(".jpg") || $0.hasSuffix(".JPG") || $0.hasSuffix(".jpeg"))
        && !$0.contains("portrait_mm_")
    }
    #expect(
      otherReencodes == [],
      "unrelated photos were re-encoded: \(otherReencodes)")

    // …nor rewritten-identical, which would mean libvips ran but
    // produced matching bytes (a wasted encode).
    let otherRewrittenScaled = scaledImagePaths(in: diff.rewrittenIdentical).filter {
      !$0.contains("portrait_mm_")
    }
    #expect(otherRewrittenScaled == [])
  }

  // MARK: - Add a photo

  @Test func addingAPhotoOnlyAddsNewOutputs() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let before = try harness.snapshotOutput()

    try await sleepPastMtimeResolution()

    // Stage a second fixture to source a fresh photo from, so we're not
    // racing against the already-staged Misc folder.
    let donor = try SourceFixture.stage(albums: ["2024"])
    defer { donor.cleanup() }
    try fixture.addPhoto(
      toAlbum: "Misc",
      fromSourceFile: donor.sourceRoot
        + "/2024/2024-06-21_Håkon_har_nytt_kamera/_DSF0055.JPG",
      as: "new_addition.JPG"
    )

    try await harness.buildAndClean()
    let after = try harness.snapshotOutput()

    let diff = before.diff(against: after)
    let added = Set(diff.added)

    #expect(added.contains("root/Misc/new_addition.json"))
    #expect(added.contains("root/Misc/new_addition_180.JPG"))
    #expect(added.contains("root/Misc/new_addition_340.JPG"))
    #expect(added.contains("root/Misc/new_addition_original.JPG"))

    // No pre-existing scaled image should have been re-encoded.
    let rewrittenScaled = scaledImagePaths(in: diff.byteChanged + diff.rewrittenIdentical)
    let unexpected = rewrittenScaled.filter { !$0.contains("new_addition_") }
    #expect(
      unexpected == [],
      "adding a photo should not touch unrelated scaled images: \(unexpected)")
  }

  // MARK: - Remove a photo

  @Test func removingAPhotoCleansOnlyThatPhotosOutputs() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let before = try harness.snapshotOutput()

    try await sleepPastMtimeResolution()
    try fixture.removePhoto(inAlbum: "Misc", named: "portrait_mm.jpeg")
    try await harness.buildAndClean()
    let after = try harness.snapshotOutput()

    let diff = before.diff(against: after)
    let removed = Set(diff.removed)

    #expect(removed.contains("root/Misc/portrait_mm.json"))
    #expect(removed.contains("root/Misc/portrait_mm_180.jpeg"))
    #expect(removed.contains("root/Misc/portrait_mm_340.jpeg"))
    #expect(removed.contains("root/Misc/portrait_mm_original.jpeg"))

    // Other Misc photos must still be on disk.
    let surviving = after.entries.keys.filter { $0.hasPrefix("root/Misc/") }
    #expect(
      surviving.contains("root/Misc/20180510-171752-IMG_7165.json"),
      "unrelated Misc photo was incorrectly deleted")

    let otherScaledRewrites = scaledImagePaths(in: diff.byteChanged + diff.rewrittenIdentical)
    #expect(
      otherScaledRewrites == [],
      "removing a photo should not re-encode other scaled images: \(otherScaledRewrites)")
  }

  // MARK: - Add an album

  @Test func addingAnAlbumOnlyEncodesThatAlbum() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let before = try harness.snapshotOutput()

    try await sleepPastMtimeResolution()
    // Create a new sub-album with one photo.
    let donor = try SourceFixture.stage(albums: ["2024"])
    defer { donor.cleanup() }
    try fixture.addPhoto(
      toAlbum: "NewAlbum",
      fromSourceFile: donor.sourceRoot
        + "/2024/2024-06-21_Håkon_har_nytt_kamera/_DSF0055.JPG",
      as: "only_photo.JPG"
    )

    try await harness.buildAndClean()
    let after = try harness.snapshotOutput()

    let diff = before.diff(against: after)
    let added = Set(diff.added)

    #expect(added.contains("root/NewAlbum"))
    #expect(added.contains("root/NewAlbum/index.json"))
    #expect(added.contains("root/NewAlbum/only_photo.json"))
    #expect(added.contains("root/NewAlbum/only_photo_180.JPG"))
    #expect(added.contains("root/NewAlbum/only_photo_340.JPG"))
    #expect(added.contains("root/NewAlbum/only_photo_original.JPG"))

    let rewrittenScaled = scaledImagePaths(in: diff.byteChanged + diff.rewrittenIdentical)
    let unrelated = rewrittenScaled.filter { !$0.contains("NewAlbum/") }
    #expect(
      unrelated == [],
      "adding an album must not re-encode unrelated scaled images: \(unrelated)")
  }

  // MARK: - Remove an album

  @Test func removingAnAlbumCleansOnlyThatAlbum() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc", "2024"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let before = try harness.snapshotOutput()

    try await sleepPastMtimeResolution()
    try fixture.removeAlbum("2024")
    try await harness.buildAndClean()
    let after = try harness.snapshotOutput()

    let diff = before.diff(against: after)

    // Every path under root/2024 must be gone.
    let removed = Set(diff.removed)
    let survivingUnder2024 = after.entries.keys.filter { $0.hasPrefix("root/2024/") }
    #expect(
      survivingUnder2024.isEmpty,
      "album folder not fully cleaned: \(survivingUnder2024.sorted())")
    #expect(
      removed.contains { $0.hasPrefix("root/2024/") },
      "expected entries under root/2024/ to appear in removed, got \(removed)")

    // Misc's scaled images must survive unchanged.
    let miscScaledRewrites = scaledImagePaths(in: diff.byteChanged + diff.rewrittenIdentical)
      .filter { $0.hasPrefix("root/Misc/") }
    #expect(
      miscScaledRewrites == [],
      "removing one album re-encoded another album's images: \(miscScaledRewrites)")
  }

  // MARK: - Rename an album

  @Test func renamingAnAlbumRemovesOldAndCreatesNew() async throws {
    let fixture = try SourceFixture.stage(albums: ["2024"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let before = try harness.snapshotOutput()

    try await sleepPastMtimeResolution()
    try fixture.renameAlbum(
      from: "2024/2024-06-21_Håkon_har_nytt_kamera",
      to: "2024/2025-01-01_Renamed_Album")
    try await harness.buildAndClean()
    let after = try harness.snapshotOutput()

    let diff = before.diff(against: after)

    // Old album folder should be gone from output, new one created.
    #expect(
      diff.removed.contains(where: { $0.contains("Håkon_har_nytt_kamera") }),
      "old album not cleaned: removed=\(diff.removed)")
    #expect(
      diff.added.contains(where: { $0.contains("2025-01-01_Renamed_Album") }),
      "new album not created: added=\(diff.added)")
  }

  // MARK: - jsonOnly mode

  @Test func jsonOnlyModeDoesNotWriteScaledImages() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    // First build writes everything (can't be jsonOnly because there's
    // no existing output yet — Gallery.build writes images on first run
    // regardless of the flag, as it must populate the tree).
    try await harness.buildAndClean()
    let before = try harness.snapshotOutput()

    try await sleepPastMtimeResolution()
    // Replace a photo's source bytes, then rebuild in jsonOnly mode.
    let donor = try SourceFixture.stage(albums: ["2024"])
    defer { donor.cleanup() }
    try fixture.replacePhoto(
      inAlbum: "Misc",
      named: "portrait_mm.jpeg",
      withSourceFile: donor.sourceRoot
        + "/2024/2024-06-21_Håkon_har_nytt_kamera/_DSF0055.JPG"
    )
    try await harness.buildAndClean(jsonOnly: true)
    let after = try harness.snapshotOutput()

    let diff = before.diff(against: after)

    // With jsonOnly, scaled images must not be rewritten even though the
    // source changed.
    let scaledRewrites = scaledImagePaths(in: diff.byteChanged + diff.rewrittenIdentical)
    #expect(
      scaledRewrites == [],
      "jsonOnly rebuild must not touch scaled images, touched: \(scaledRewrites)")
    // The replaced photo's JSON must still reflect the new sourceHash.
    #expect(
      diff.byteChanged.contains(where: { $0.hasSuffix("Misc/portrait_mm.json") }),
      "replaced photo's JSON must update even in jsonOnly mode")
  }

  // MARK: - Resolution change invalidates every image

  @Test func addingAResolutionReencodesEveryPhoto() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    // First build at the default two-resolution set.
    let harnessLow = GalleryHarness(
      sourceRoot: fixture.sourceRoot, name: "root", resolutions: [180])
    defer { harnessLow.cleanup() }
    try await harnessLow.buildAndClean()
    let before = try harnessLow.snapshotOutput()

    // Second build on the same output dir, but with an extra resolution.
    // This changes every photo's `scaledPhotos` array → Photo != Photo
    // under the new equality → every photo is in `changedContent`.
    let harnessHigh = GalleryHarness(
      sourceRoot: fixture.sourceRoot, name: "root", resolutions: [180, 340])
    // Overlay onto the same output by copying it over. GalleryHarness
    // allocates its own output, so we swap by pointing the new harness's
    // config at the old dir via manual config construction would be
    // fiddly; instead, just rebuild using the old harness with new
    // resolutions by doing the ConfigurationManager ritual directly.
    let manager = ConfigurationManager()
    manager.load([
      "name": "root",
      "resolutions": [180, 340],
      "sourceFolder": fixture.sourceRoot,
      "targetFolder": harnessLow.outputRoot,
      "fileExtensions": ["jpg", "jpeg", "JPG", "JPEG"],
      "progress": false,
      "concurrency": 1,
    ])
    _ = harnessHigh  // suppress "unused" warning
    let cfg = GalleryConfiguration(manager)
    let ctx = Context(config: cfg)
    try await sleepPastMtimeResolution()
    let gallery = try await Gallery.load(ctx: ctx)
    try await gallery.build(ctx: ctx, jsonOnly: false)
    gallery.clean(ctx: ctx)

    let after = try harnessLow.snapshotOutput()
    let diff = before.diff(against: after)

    let added = Set(diff.added)
    // The new 340-size variants should appear for every photo that had a
    // 180 before.
    let new340 = added.filter { $0.hasSuffix("_340.jpg") || $0.hasSuffix("_340.jpeg") }
    #expect(
      !new340.isEmpty,
      "adding a resolution did not produce any _340 files")

    // The existing _180 scaled images should have been re-encoded (new
    // bytes) or at minimum rewritten-identical. Content determinism of
    // libvips re-encoding the same source is not guaranteed across
    // invocations, so accept either `byteChanged` or `rewrittenIdentical`.
    let existing180Rewritten = diff.byteChanged + diff.rewrittenIdentical
    let touched180 = existing180Rewritten.filter {
      $0.hasSuffix("_180.jpg") || $0.hasSuffix("_180.jpeg")
    }
    #expect(
      !touched180.isEmpty,
      "adding a resolution should re-run encoding for existing photos too")
  }

  // MARK: - Helpers

  /// Sleep long enough that any subsequent file write lands on a
  /// distinct mtime on every filesystem the test suite runs on. HFS+ on
  /// older macOS truncates mtime to whole seconds, which is the
  /// worst-case resolution we care about.
  private func sleepPastMtimeResolution() async throws {
    try await Task.sleep(nanoseconds: 1_100_000_000)
  }

  /// Filter a list of paths down to the scaled-image outputs Munin emits
  /// (`_NNN.jpg`, `_NNN.jpeg`, `_NNN.JPG`). Used to assert "no scaled
  /// image was rewritten" without also catching `_original.*` symlinks.
  private func scaledImagePaths(in paths: [String]) -> [String] {
    let patterns = ["jpg", "jpeg", "JPG", "JPEG"]
    return paths.filter { path in
      guard patterns.contains(where: { path.hasSuffix(".\($0)") }) else { return false }
      // Exclude `_original` symlinks; only the sized scaled variants
      // matter for "was libvips re-run".
      let stem = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
      return stem.contains("_") && !stem.hasSuffix("_original")
    }
  }

  /// Recursively bump the modification time of every photo (`*.jpg`,
  /// `*.jpeg`, `*.JPG`, `*.JPEG`) under `root` to "now".
  private func touchEverySourcePhoto(under root: String) throws {
    let fm = FileManager.default
    guard
      let enumerator = fm.enumerator(
        at: URL(fileURLWithPath: root), includingPropertiesForKeys: nil)
    else { return }
    let extensions: Set<String> = ["jpg", "jpeg", "JPG", "JPEG"]
    let now = Date()
    for case let url as URL in enumerator {
      guard extensions.contains(url.pathExtension) else { continue }
      try fm.setAttributes([.modificationDate: now], ofItemAtPath: url.path)
    }
  }

  // MARK: - Full-gallery scenarios
  //
  // These ten tests stage the complete `example/album` tree and walk
  // realistic user workflows (edit none / edit some / edit all / mixed /
  // multi-round / adversarial / known-gap), asserting both content-level
  // diffs and hash-call ceilings. Seeds are per-scenario constants so
  // failures are reproducible and each test exercises a different subset
  // of the 104-photo tree.

  /// #1 — edit nothing, rebuild three times. Every rebuild must be a
  /// complete no-op at the image level and every rebuild must hash zero
  /// source files. (Three rounds is enough to catch "the cache works on
  /// rebuild N but breaks on rebuild N+1"; more rounds only adds time.)
  @Test func editNone_threeRebuildsStayQuiet() async throws {
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    var previous = try harness.snapshotOutput()

    for round in 1...3 {
      try await sleepPastMtimeResolution()

      ContentHash.resetCallCount()
      try await harness.buildAndClean()
      let current = try harness.snapshotOutput()

      let hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
      #expect(
        hashes == 0,
        "round \(round): expected 0 hashes on a no-op rebuild, got \(hashes)")

      let diff = previous.diff(against: current)
      let classification = RebuildClassification(
        from: diff, before: previous, after: current)

      #expect(
        classification.scaledImagesReencoded == [],
        "round \(round) re-encoded scaled images:\n\(classification.summary)")
      #expect(
        classification.scaledImagesRewrittenSameBytes == [],
        "round \(round) rewrote scaled images with identical bytes:\n\(classification.summary)"
      )
      #expect(
        classification.originalSymlinksAdded == [],
        "round \(round) added original symlinks:\n\(classification.summary)")
      #expect(
        classification.originalSymlinksRemoved == [],
        "round \(round) removed original symlinks:\n\(classification.summary)")

      previous = current
    }
  }

  /// #2 — "edit some": replace the bytes of seven seeded-random photos
  /// spanning multiple albums. Exactly those seven photos' scaled
  /// outputs must be re-encoded; everything else must be untouched.
  @Test func editSome_replaceSevenPhotosReencodesOnlyThose() async throws {
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let before = try harness.snapshotOutput()

    // "edit some" as hex, mnemonic per this scenario.
    let seed: UInt64 = 0xED17_5073
    let targets = fixture.pickRandomPhotos(count: 7, seed: seed)
    #expect(targets.count == 7)

    // Donor pool: every photo NOT in `targets`, as absolute origin paths.
    // The round-robin replacement will give each target a different-
    // bytes replacement drawn from the existing example set.
    let donorPool = fixture.allPhotos
      .filter { !targets.contains($0) }
      .map { fixture.originPhoto($0) }
    try fixture.replacePhotos(targets, withDonorPool: donorPool)

    try await sleepPastMtimeResolution()
    ContentHash.resetCallCount()
    try await harness.buildAndClean()
    let after = try harness.snapshotOutput()

    let hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(
      hashes == 7,
      "expected exactly 7 hashes for 7 replaced photos, got \(hashes)")

    let diff = before.diff(against: after)
    let classification = RebuildClassification(
      from: diff, before: before, after: after)

    // At resolutions=[180, 340] every replaced photo produces exactly
    // two scaled outputs, all of which must be byte-changed.
    #expect(
      classification.scaledImagesReencoded.count == 7 * 2,
      "expected 14 scaled images re-encoded, got \(classification.scaledImagesReencoded.count):\n\(classification.summary)"
    )
    #expect(
      classification.scaledImagesRewrittenSameBytes == [],
      "unrelated scaled images were rewritten with identical bytes:\n\(classification.summary)"
    )
    // Sanity: scaled output paths correspond to the seven target stems.
    for target in targets {
      let stem = URL(fileURLWithPath: target).deletingPathExtension().lastPathComponent
      let hits = classification.scaledImagesReencoded.filter { $0.contains(stem + "_") }
      #expect(hits.count == 2, "expected 2 scaled outputs for \(stem), got \(hits.count)")
    }
  }

  /// #3/#4 — "edit all": replace every single source photo, verify a
  /// full re-encode, then confirm the next rebuild is a complete no-op
  /// (the cache recovers from full churn).
  @Test func editAll_replaceEveryPhotoThenRebuildIsQuiet() async throws {
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let baseline = try harness.snapshotOutput()

    // Donor pool: every staged photo, rotated so each target gets a
    // different donor than itself (swap-style). Using all photos as
    // both targets and donors means each photo gets someone else's
    // bytes, guaranteeing content drift across the whole tree.
    let allPhotos = fixture.allPhotos
    #expect(allPhotos.count == 104, "expected 104 example photos, got \(allPhotos.count)")

    let rotatedDonors = Array(allPhotos.dropFirst()) + [allPhotos.first!]
    let donorAbsolute = rotatedDonors.map { fixture.originPhoto($0) }
    try fixture.replacePhotos(allPhotos, withDonorPool: donorAbsolute)

    try await sleepPastMtimeResolution()
    ContentHash.resetCallCount()
    try await harness.buildAndClean()
    let afterReplace = try harness.snapshotOutput()

    let hashesAfterReplace = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(
      hashesAfterReplace == 104,
      "full replacement should hash all 104 photos, got \(hashesAfterReplace)")

    let replaceDiff = baseline.diff(against: afterReplace)
    let replaceClass = RebuildClassification(
      from: replaceDiff, before: baseline, after: afterReplace)
    #expect(
      replaceClass.scaledImagesReencoded.count == 104 * 2,
      "expected 208 scaled images re-encoded, got \(replaceClass.scaledImagesReencoded.count)"
    )
    #expect(
      replaceClass.scaledImagesRewrittenSameBytes == [],
      "full replacement produced wasted identical encodes:\n\(replaceClass.summary)")

    // Second rebuild: must be a no-op.
    try await sleepPastMtimeResolution()
    ContentHash.resetCallCount()
    try await harness.buildAndClean()
    let afterQuiet = try harness.snapshotOutput()

    let hashesAfterQuiet = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(
      hashesAfterQuiet == 0,
      "post-replace quiet rebuild hashed \(hashesAfterQuiet) files; cache failed to absorb the replacement"
    )

    let quietDiff = afterReplace.diff(against: afterQuiet)
    let quietClass = RebuildClassification(
      from: quietDiff, before: afterReplace, after: afterQuiet)
    #expect(
      quietClass.scaledImagesReencoded == [],
      "quiet rebuild re-encoded scaled images:\n\(quietClass.summary)")
    #expect(
      quietClass.scaledImagesRewrittenSameBytes == [],
      "quiet rebuild rewrote scaled images identically:\n\(quietClass.summary)")
  }

  /// #5 — touch every source mtime on the full gallery. The next build
  /// hashes each file exactly once (to prove bytes are unchanged) and
  /// then subsequent rebuilds return to zero hashing. No scaled image is
  /// ever re-encoded.
  @Test func mtimeDriftAtFullScaleIsOptimal() async throws {
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let baseline = try harness.snapshotOutput()

    try await sleepPastMtimeResolution()
    try fixture.touchPhotos(fixture.allPhotos)

    ContentHash.resetCallCount()
    try await harness.buildAndClean()
    let afterDrift = try harness.snapshotOutput()

    let driftHashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(
      driftHashes == 104,
      "touching 104 mtimes should hash all 104 once; got \(driftHashes)")

    let driftDiff = baseline.diff(against: afterDrift)
    let driftClass = RebuildClassification(
      from: driftDiff, before: baseline, after: afterDrift)
    #expect(
      driftClass.scaledImagesReencoded == [],
      "mtime drift re-encoded scaled images:\n\(driftClass.summary)")
    #expect(
      driftClass.scaledImagesRewrittenSameBytes == [],
      "mtime drift rewrote scaled images identically:\n\(driftClass.summary)")

    // Now the cache has absorbed the new mtimes — the next rebuild is
    // free again.
    try await sleepPastMtimeResolution()
    ContentHash.resetCallCount()
    try await harness.buildAndClean()

    let quietHashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(
      quietHashes == 0,
      "post-drift rebuild still hashed \(quietHashes) files; cache was not updated")
  }

  /// #6 — mixed mutations in one rebuild: three photos added, three
  /// removed, three byte-replaced. Each category's output must show
  /// exactly the expected delta; nothing else must move.
  @Test func mixedMutations_addRemoveModifyInOneRebuild() async throws {
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let before = try harness.snapshotOutput()

    let mixedSeed: UInt64 = 0x1EDA_5EED
    let toReplace = fixture.pickRandomPhotos(count: 3, seed: mixedSeed)
    let remainingAfterReplace = fixture.allPhotos.filter { !toReplace.contains($0) }
    // Pick more than 3 to leave room for filtering — pickRandomPhotos
    // draws from the full pool which could overlap with `toReplace`.
    let toRemove = Array(
      fixture.pickRandomPhotos(count: 10, seed: mixedSeed &+ 1)
        .filter { !toReplace.contains($0) }
        .prefix(3)
    )
    #expect(toRemove.count == 3, "unable to pick 3 distinct removal targets")

    // Replace: use other photos as donors.
    let donorPool =
      remainingAfterReplace
      .filter { !toRemove.contains($0) }
      .map { fixture.originPhoto($0) }
    try fixture.replacePhotos(toReplace, withDonorPool: donorPool)

    // Remove.
    try fixture.removePhotos(toRemove)

    // Add three new photos to Misc. Source them from 2017 (known to
    // always have >3 photos).
    let donorsForAdd =
      (try? FileManager.default.contentsOfDirectory(
        atPath: fixture.originRoot + "/2017/2017-12-22 Juleferie")) ?? []
    let addDonorPaths = donorsForAdd.prefix(3).map {
      fixture.originRoot + "/2017/2017-12-22 Juleferie/" + $0
    }
    #expect(addDonorPaths.count == 3)
    for (idx, donor) in addDonorPaths.enumerated() {
      try fixture.addPhoto(
        toAlbum: "Misc",
        fromSourceFile: donor,
        as: "added_\(idx).jpg"
      )
    }

    try await sleepPastMtimeResolution()
    ContentHash.resetCallCount()
    try await harness.buildAndClean()
    let after = try harness.snapshotOutput()

    let hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(
      hashes == 6,
      "mixed (3 replace + 3 add + 3 remove) should hash 6, got \(hashes)")

    let diff = before.diff(against: after)
    let classification = RebuildClassification(
      from: diff, before: before, after: after)

    // 3 added × 2 scaled = 6 new scaled jpegs added.
    // 3 replaced × 2 scaled = 6 byte-changed.
    // 3 removed × 2 scaled = 6 removed (present in classification's
    // reencoded bucket per the "A scaled image removed means encoding
    // went away" rule). Grand total: 18.
    #expect(
      classification.scaledImagesReencoded.count == 18,
      "mixed mutation scaled-image delta: \(classification.scaledImagesReencoded.count)\n\(classification.summary)"
    )
    // Symlinks: 3 added for added photos, 3 removed for removed photos.
    #expect(
      classification.originalSymlinksAdded.count == 3,
      "expected 3 new original symlinks, got \(classification.originalSymlinksAdded.count)")
    #expect(
      classification.originalSymlinksRemoved.count == 3,
      "expected 3 removed original symlinks, got \(classification.originalSymlinksRemoved.count)")
  }

  /// #7 — a five-round evolution simulating a user working with their
  /// gallery over time. Each round's specific expectations are asserted
  /// against the snapshot from the previous round.
  @Test func multiRoundEvolution() async throws {
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    var previous = try harness.snapshotOutput()

    // R1: touch 10 random mtimes.
    try await sleepPastMtimeResolution()
    let touchSeed: UInt64 = 0x0701_C470  // "touch r1" vaguely
    let r1Targets = fixture.pickRandomPhotos(count: 10, seed: touchSeed)
    try fixture.touchPhotos(r1Targets)
    ContentHash.resetCallCount()
    try await harness.buildAndClean()
    var current = try harness.snapshotOutput()
    var hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(hashes == 10, "R1 (touch 10) expected 10 hashes, got \(hashes)")
    var cls = RebuildClassification(
      from: previous.diff(against: current), before: previous, after: current)
    #expect(
      cls.scaledImagesReencoded == [],
      "R1 (touch only) must not re-encode images:\n\(cls.summary)")
    previous = current

    // R2: replace 3 random photos.
    try await sleepPastMtimeResolution()
    let replaceSeed: UInt64 = 0x2222_2222
    let r2Targets = fixture.pickRandomPhotos(count: 3, seed: replaceSeed)
    let r2Donors = fixture.allPhotos
      .filter { !r2Targets.contains($0) }
      .map { fixture.originPhoto($0) }
    try fixture.replacePhotos(r2Targets, withDonorPool: r2Donors)
    ContentHash.resetCallCount()
    try await harness.buildAndClean()
    current = try harness.snapshotOutput()
    hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(hashes == 3, "R2 (replace 3) expected 3 hashes, got \(hashes)")
    cls = RebuildClassification(
      from: previous.diff(against: current), before: previous, after: current)
    #expect(
      cls.scaledImagesReencoded.count == 6,
      "R2 scaled re-encodes: \(cls.scaledImagesReencoded.count)\n\(cls.summary)")
    previous = current

    // R3: clone an album. Pick Misc (three photos, pure ASCII).
    try await sleepPastMtimeResolution()
    try fixture.cloneAlbum(originRelative: "Misc", asNewName: "MiscClone")
    let clonedPhotos =
      (try? FileManager.default.contentsOfDirectory(
        atPath: fixture.sourceRoot + "/MiscClone"))?.filter {
        $0.hasSuffix(".jpg") || $0.hasSuffix(".jpeg")
      } ?? []
    ContentHash.resetCallCount()
    try await harness.buildAndClean()
    current = try harness.snapshotOutput()
    hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(
      hashes == clonedPhotos.count,
      "R3 (clone Misc) expected \(clonedPhotos.count) hashes, got \(hashes)")
    // New scaled images must appear under root/MiscClone/.
    let newMiscCloneScaled = current.entries.keys.filter {
      $0.hasPrefix("root/MiscClone/") && ($0.hasSuffix(".jpg") || $0.hasSuffix(".jpeg"))
        && !$0.hasSuffix("_original.jpg") && !$0.hasSuffix("_original.jpeg")
    }
    #expect(
      !newMiscCloneScaled.isEmpty,
      "R3 clone produced no scaled outputs under root/MiscClone/")
    previous = current

    // R4: delete 2017 album (a whole year, three sub-albums).
    try await sleepPastMtimeResolution()
    try fixture.removeAlbum("2017")
    ContentHash.resetCallCount()
    try await harness.buildAndClean()
    current = try harness.snapshotOutput()
    hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(hashes == 0, "R4 (delete album, no reads required) expected 0 hashes, got \(hashes)")
    let survivingUnder2017 = current.entries.keys.filter { $0.hasPrefix("root/2017/") }
    #expect(
      survivingUnder2017.isEmpty,
      "R4: root/2017/ should be fully cleaned, still present: \(survivingUnder2017.sorted().prefix(3))"
    )
    previous = current

    // R5: nothing changed. Rebuild must be entirely quiet.
    try await sleepPastMtimeResolution()
    ContentHash.resetCallCount()
    try await harness.buildAndClean()
    current = try harness.snapshotOutput()
    hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(hashes == 0, "R5 quiet rebuild hashed \(hashes) files")
    cls = RebuildClassification(
      from: previous.diff(against: current), before: previous, after: current)
    #expect(
      cls.scaledImagesReencoded == [],
      "R5 should re-encode nothing:\n\(cls.summary)")
    #expect(
      cls.scaledImagesRewrittenSameBytes == [],
      "R5 should not rewrite scaled images identically:\n\(cls.summary)")
  }

  /// #8 — swap the bytes of two photos. Munin should treat both as
  /// changed even though the *set* of scaled output paths is unchanged.
  @Test func adversarial_swapTwoPhotosBytes() async throws {
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()
    let before = try harness.snapshotOutput()

    // Two specific photos from 2017-12-19 Aarhus, chosen so both always
    // exist in the fixture and both are full-resolution cameras shots.
    let albumRel = "2017/2017-12-19 Aarhus"
    let nameA = "20171219-132134-20171219-IMG_5239.jpg"
    let nameB = "20171219-132212-20171219-IMG_5241.jpg"

    let srcRoot = fixture.sourceRoot
    let pathA = srcRoot + "/" + albumRel + "/" + nameA
    let pathB = srcRoot + "/" + albumRel + "/" + nameB

    let dataA = try Data(contentsOf: URL(fileURLWithPath: pathA))
    let dataB = try Data(contentsOf: URL(fileURLWithPath: pathB))
    try dataB.write(to: URL(fileURLWithPath: pathA))
    try dataA.write(to: URL(fileURLWithPath: pathB))

    try await sleepPastMtimeResolution()
    ContentHash.resetCallCount()
    try await harness.buildAndClean()
    let after = try harness.snapshotOutput()

    let hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(hashes == 2, "swap should hash exactly 2 files, got \(hashes)")

    let diff = before.diff(against: after)
    let classification = RebuildClassification(
      from: diff, before: before, after: after)

    // Both photos' scaled outputs must be re-encoded (2 × 2 = 4); no
    // other scaled image should be touched.
    let scaledForSwap = classification.scaledImagesReencoded.filter {
      $0.contains("IMG_5239") || $0.contains("IMG_5241")
    }
    #expect(
      scaledForSwap.count == 4,
      "swap should re-encode 4 scaled images, got \(scaledForSwap.count): \(scaledForSwap)")
    let unrelatedScaled = classification.scaledImagesReencoded.filter {
      !$0.contains("IMG_5239") && !$0.contains("IMG_5241")
    }
    #expect(
      unrelatedScaled == [],
      "swap re-encoded unrelated scaled images: \(unrelatedScaled)")
  }

  /// #9 — delete a photo, rebuild+clean, then add a different photo
  /// under the same relative path. The re-added photo must be treated
  /// as fresh (one hash, new outputs with new bytes).
  @Test func adversarial_readdDeletedNameWithDifferentBytes() async throws {
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()

    let victim = "Misc/portrait_mm.jpeg"

    // Step 1: remove, rebuild+clean.
    try await sleepPastMtimeResolution()
    try fixture.removePhotos([victim])
    try await harness.buildAndClean()
    let afterDelete = try harness.snapshotOutput()
    #expect(
      !afterDelete.entries.keys.contains("root/Misc/portrait_mm.json"),
      "delete+clean should remove portrait_mm's JSON")

    // Step 2: re-add with completely different bytes at the same name.
    try await sleepPastMtimeResolution()
    try fixture.addPhoto(
      toAlbum: "Misc",
      fromSourceFile: fixture.originPhoto(
        "2024/2024-06-21_Håkon_har_nytt_kamera/_DSF0055.JPG"),
      as: "portrait_mm.jpeg"
    )
    ContentHash.resetCallCount()
    try await harness.buildAndClean()
    let afterReadd = try harness.snapshotOutput()

    let hashes = ContentHash.callCount(forPathsUnder: fixture.sourceRoot)
    #expect(hashes == 1, "re-add should hash only the new file, got \(hashes)")
    #expect(
      afterReadd.entries.keys.contains("root/Misc/portrait_mm.json"),
      "re-add should recreate the photo JSON")
    #expect(
      afterReadd.entries.keys.contains("root/Misc/portrait_mm_180.jpeg"),
      "re-add should recreate the 180px scaled output")
    #expect(
      afterReadd.entries.keys.contains("root/Misc/portrait_mm_340.jpeg"),
      "re-add should recreate the 340px scaled output")
  }

  /// #10 — a scaled JPEG deleted from the output tree while the source
  /// is unchanged is regenerated on the next rebuild.
  /// `readStateFromOutputDirectory` prunes photos whose expected outputs
  /// are incomplete, so the diff treats them as added and Pass 1 of
  /// `Gallery.build` re-encodes their images.
  @Test func missingScaledOutputIsAutoHealed() async throws {
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.buildAndClean()

    // Sanity: the file we're about to delete actually exists first.
    let missingPath = harness.outputRoot + "/root/Misc/portrait_mm_180.jpeg"
    let siblingJsonPath = harness.outputRoot + "/root/Misc/portrait_mm.json"
    #expect(
      FileManager.default.fileExists(atPath: missingPath),
      "precondition: baseline build should produce portrait_mm_180.jpeg")
    #expect(
      FileManager.default.fileExists(atPath: siblingJsonPath),
      "precondition: baseline build should produce portrait_mm.json")

    try FileManager.default.removeItem(atPath: missingPath)

    try await sleepPastMtimeResolution()
    try await harness.buildAndClean()

    #expect(
      FileManager.default.fileExists(atPath: missingPath),
      "self-heal should have regenerated portrait_mm_180.jpeg")
    #expect(
      FileManager.default.fileExists(atPath: siblingJsonPath),
      "self-heal should leave portrait_mm.json in place")
  }

  /// #11 — changing `jpegCompression` between two rebuilds re-encodes
  /// every scaled output. Without `encodingFingerprint` on `Photo.==`
  /// the on-disk JPEGs silently keep their old quality.
  @Test func jpegCompressionChangeReencodesAllScaledImages() async throws {
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let low = GalleryHarness(
      sourceRoot: fixture.sourceRoot, name: "root", jpegCompression: 0.5)
    defer { low.cleanup() }
    try await low.buildAndClean()
    let before = try low.snapshotOutput()

    // Count the baseline's scaled JPEGs so we can assert "every one of
    // them was re-encoded" without hard-coding per-fixture expectations.
    // The fixture spans `.jpg` and `.jpeg` sources, so match on the
    // `_<resolution>.` stem convention rather than a fixed extension.
    let scaledPaths = before.entries.keys.filter {
      $0.contains("_180.") || $0.contains("_340.")
    }
    #expect(!scaledPaths.isEmpty, "baseline should produce scaled images to compare against")

    try await sleepPastMtimeResolution()

    let high = GalleryHarness(
      sourceRoot: fixture.sourceRoot,
      name: "root",
      jpegCompression: 0.9,
      outputRoot: low.outputRoot)
    try await high.buildAndClean()
    let after = try high.snapshotOutput()

    let diff = before.diff(against: after)
    let classification = RebuildClassification(from: diff, before: before, after: after)

    #expect(
      classification.scaledImagesReencoded.count == scaledPaths.count,
      """
      expected all \(scaledPaths.count) scaled images re-encoded after \
      jpegCompression change, got \(classification.scaledImagesReencoded.count):
      \(classification.summary)
      """
    )
    #expect(
      classification.scaledImagesRewrittenSameBytes == [],
      """
      changing jpegCompression should never produce identical-byte rewrites:
      \(classification.summary)
      """
    )
  }
}
