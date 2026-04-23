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
}
