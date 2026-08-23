import Foundation
import Testing

@testable import MuninKit

/// Munin derives every output path from the *name* of its source, dropping
/// the file extension for photo JSON, urlifying directory names, and
/// urlifying keyword names into `keywords/<name>.json`. That map is not
/// injective: two sources can want the same output path. When they do, the
/// surviving file is whichever write landed last, so the same input
/// produces different output on consecutive runs — and one of the user's
/// photos is silently missing from the gallery, or from the keyword page
/// its own metadata links to.
///
/// These tests pin the contract: a build whose output paths are not
/// injective fails, names every source involved, and does not touch the
/// previous output. Both halves of the check are covered — the filename
/// walk that runs before the read, and the keyword pass that runs after it
/// (keyword names live in EXIF) but still before anything is written.
@Suite(.serialized)
struct OutputPathCollisionTests {

  // MARK: - Helpers

  /// Run `Gallery.load` and return the collisions it refused to build on.
  /// Records an issue (rather than throwing) if the build unexpectedly
  /// succeeded or failed for some other reason, so a failure message says
  /// what actually happened.
  private func collisions(from harness: GalleryHarness) async -> [OutputPathCollision] {
    do {
      _ = try await harness.load()
      Issue.record("expected the build to fail with an output path collision, but it succeeded")
      return []
    } catch let error as MuninError {
      guard case .outputPathCollision(let found) = error else {
        Issue.record("expected .outputPathCollision, got \(error)")
        return []
      }
      return found
    } catch {
      Issue.record("expected MuninError.outputPathCollision, got \(error)")
      return []
    }
  }

  /// Same, for the keyword namespace, which is checked after the read.
  private func keywordCollisions(from harness: GalleryHarness) async -> [OutputPathCollision] {
    do {
      _ = try await harness.load()
      Issue.record("expected the build to fail with a keyword path collision, but it succeeded")
      return []
    } catch let error as MuninError {
      guard case .keywordPathCollision(let found) = error else {
        Issue.record("expected .keywordPathCollision, got \(error)")
        return []
      }
      return found
    } catch {
      Issue.record("expected MuninError.keywordPathCollision, got \(error)")
      return []
    }
  }

  /// An album carrying keyword/people pointers directly, so the keyword
  /// namespace can be exercised without authoring IPTC metadata.
  private func album(
    keywords: [KeywordPointer], people: [KeywordPointer] = []
  ) -> Album {
    var album = Album(name: "root", path: "out/root", parents: [])
    album.keywords = Set(keywords)
    album.people = Set(people)
    return album
  }

  private func pointer(_ name: String) -> KeywordPointer {
    KeywordPointer(name: name, url: "out/keywords/\(urlifyName(name)).json")
  }

  private func jpeg(_ fixture: SourceFixture) -> String {
    fixture.originPhoto("Misc/test_special_chars.jpg")
  }

  private func jpeg2(_ fixture: SourceFixture) -> String {
    fixture.originPhoto("Misc/portrait_mm.jpeg")
  }

  // MARK: - Photo JSON collisions

  /// `sample.jpg` and `sample.jpeg` both reduce to `sample.json`. Both
  /// extensions are in the stock `fileExtensions`, so this needs no
  /// configuration at all.
  @Test func sameBasenameDifferentExtensionFailsTheBuild() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }
    try fixture.addPhoto(
      toAlbum: "Coll", fromSourceFile: jpeg(fixture), as: "sample.jpg")
    try fixture.addPhoto(
      toAlbum: "Coll", fromSourceFile: jpeg2(fixture), as: "sample.jpeg")

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }

    let found = await collisions(from: harness)
    #expect(found.count == 1, "expected exactly one collision, got \(found)")
    let collision = try #require(found.first)
    #expect(collision.outputPath.hasSuffix("/root/Coll/sample.json"))
    #expect(
      collision.sources == [
        fixture.sourceRoot + "/Coll/sample.jpeg",
        fixture.sourceRoot + "/Coll/sample.jpg",
      ],
      "both sources must be named, sorted: \(collision.sources)")
  }

  /// The same defect through case alone — `sample.jpg` / `sample.JPG` are
  /// distinct files on a case-sensitive filesystem and both are in the
  /// default extension list.
  ///
  /// Skipped where the filesystem folds the two names into one (APFS, and
  /// so the `macos-latest` CI leg): the fixture cannot be built there, and
  /// a skip that says so beats a pass against a one-file tree.
  @Test(.enabled(if: SourceFixture.filesystemDistinguishesCase))
  func sameBasenameDifferingOnlyByExtensionCaseFailsTheBuild() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }
    try fixture.addPhoto(toAlbum: "Coll", fromSourceFile: jpeg(fixture), as: "sample.jpg")
    try fixture.addPhoto(toAlbum: "Coll", fromSourceFile: jpeg2(fixture), as: "sample.JPG")

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }

    let found = await collisions(from: harness)
    #expect(found.count == 1, "expected exactly one collision, got \(found)")
  }

  /// A photo literally named `index` claims the album's own `index.json`.
  /// Same broken invariant, and the loser is the whole album listing.
  @Test func photoNamedIndexCollidesWithTheAlbumListing() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }
    try fixture.addPhoto(toAlbum: "Coll", fromSourceFile: jpeg(fixture), as: "index.jpg")

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }

    let found = await collisions(from: harness)
    let collision = try #require(found.first)
    #expect(collision.outputPath.hasSuffix("/root/Coll/index.json"))
    #expect(collision.sources.contains(fixture.sourceRoot + "/Coll/index.jpg"))
    #expect(collision.sources.contains(fixture.sourceRoot + "/Coll"))
  }

  // MARK: - Album directory collisions

  /// `urlifyName` maps space to underscore, so two sibling source
  /// directories that differ only by that character share one output
  /// directory. This is the most destructive variant: each album's
  /// `clean` deletes the other's photos, and it is reachable with the
  /// stock JPEG-only extension list.
  @Test func siblingAlbumsThatUrlifyToTheSameNameFailTheBuild() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }
    try fixture.addPhoto(toAlbum: "My Album", fromSourceFile: jpeg(fixture), as: "one.jpg")
    try fixture.addPhoto(toAlbum: "My_Album", fromSourceFile: jpeg2(fixture), as: "two.jpg")

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }

    let found = await collisions(from: harness)
    #expect(found.count == 1, "expected exactly one collision, got \(found)")
    let collision = try #require(found.first)
    #expect(collision.outputPath.hasSuffix("/root/My_Album"))
    #expect(
      collision.sources == [
        fixture.sourceRoot + "/My Album",
        fixture.sourceRoot + "/My_Album",
      ],
      "both source directories must be named: \(collision.sources)")
  }

  // MARK: - Keyword page collisions

  /// The third information-losing derivation: keyword pages are
  /// `keywords/<urlifyName(name)>.json`, so two spellings that differ only
  /// where `urlifyName` maps space to underscore share one page. The
  /// loser's photos link to a page that does not list them.
  @Test func keywordsThatUrlifyToTheSamePageAreReported() throws {
    let found = findKeywordOutputPathCollisions(
      album: album(keywords: [
        pointer("Tel Aviv District"), pointer("Tel_Aviv_District"), pointer("Israel"),
      ]))

    #expect(found.count == 1, "expected exactly one collision, got \(found)")
    let collision = try #require(found.first)
    #expect(collision.outputPath == "out/keywords/Tel_Aviv_District.json")
    #expect(
      collision.sources == ["keyword \"Tel Aviv District\"", "keyword \"Tel_Aviv_District\""],
      "both spellings must be named: \(collision.sources)")
  }

  /// Keywords and people are written into one directory by two separate
  /// passes of `Gallery.build`, so a check that only looked at `keywords`
  /// would miss half the namespace. One name cannot be in both buckets
  /// (`applyConfigDerivedFields` re-splits the union against
  /// `allPeople`, so the bucket is a function of the name), but two names
  /// that urlify alike can be, one per bucket.
  @Test func aKeywordAndAPersonPageThatShareAFileAreReported() {
    let found = findKeywordOutputPathCollisions(
      album: album(keywords: [pointer("Blue Hour")], people: [pointer("Blue_Hour")]))

    #expect(found.count == 1, "expected exactly one collision, got \(found)")
    #expect(found.first?.outputPath == "out/keywords/Blue_Hour.json")
    #expect(found.first?.sources == ["keyword \"Blue Hour\"", "person \"Blue_Hour\""])
  }

  /// The report's own ordering, exercised. Claims accumulate in a
  /// `Dictionary` keyed by output path and Swift randomises its hash seed
  /// per process, so without the final sort a build with more than one
  /// keyword collision prints them in a different order every run — the
  /// error message shuffling between runs of the same failing build.
  ///
  /// Five collisions, not two: an unsorted list matches the sorted one by
  /// chance with probability 1/n!, so two pairs would let the mutation
  /// survive half the time. At five it is 1 in 120.
  @Test func everyKeywordCollisionIsReportedInAStableOrder() {
    let found = findKeywordOutputPathCollisions(
      album: album(keywords: [
        pointer("Tel Aviv District"), pointer("Tel_Aviv_District"),
        pointer("Blue Hour"), pointer("Blue_Hour"),
        pointer("Golden Hour"), pointer("Golden_Hour"),
        pointer("Night Sky"), pointer("Night_Sky"),
        pointer("Sea Ice"), pointer("Sea_Ice"),
      ]))

    #expect(
      found.map(\.outputPath) == [
        "out/keywords/Blue_Hour.json",
        "out/keywords/Golden_Hour.json",
        "out/keywords/Night_Sky.json",
        "out/keywords/Sea_Ice.json",
        "out/keywords/Tel_Aviv_District.json",
      ], "collisions must be reported in a stable order, got \(found.map(\.outputPath))")
  }

  /// Negative control, matching the filename namespace: NFC and NFD
  /// spellings urlify to two byte-distinct pages, so they are not a
  /// collision here. (They are a different defect — the aggregation merges
  /// them and drops one url.)
  @Test func canonicallyEquivalentKeywordsAreNotACollision() {
    let found = findKeywordOutputPathCollisions(
      album: album(keywords: [pointer("H\u{00e5}kon"), pointer("Ha\u{030a}kon")]))

    #expect(found.isEmpty, "canonically-equivalent keywords must not collide: \(found)")
  }

  /// End to end, through a real build of two photos whose IPTC keywords
  /// differ only where `urlifyName` maps space to underscore.
  ///
  /// The names live in metadata, so the check cannot run before the read
  /// the way the filename walk does. This pins where it *does* run: the
  /// build fails, and it fails having written nothing — which is the
  /// property that makes a post-read check as safe as a pre-read one.
  @Test func aKeywordCollisionInRealMetadataFailsTheBuild() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }
    let donor = fixture.originPhoto("Misc/20180510-171752-IMG_7165.jpg")
    // Two keywords each, not one: SwiftExif 0.1.0 drops the keyword list of
    // a photo that has exactly one (`IptcData.toDict` stores a lone
    // occurrence as `String` and `makeIptcFields` reads `as? [String]`), so
    // a single-keyword fixture would make this pass vacuously.
    try fixture.addPhoto(
      toAlbum: "Tagged", fromSourceFile: donor, as: "one.jpg",
      iptcKeywords: ["Blue Hour", "Nightfall"])
    try fixture.addPhoto(
      toAlbum: "Tagged", fromSourceFile: fixture.originPhoto("Misc/portrait_mm.jpeg"),
      as: "two.jpg", iptcKeywords: ["Blue_Hour", "Nightfall"])

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }

    let found = await keywordCollisions(from: harness)
    #expect(found.count == 1, "expected exactly one collision, got \(found)")
    let collision = try #require(found.first)
    #expect(collision.outputPath.hasSuffix("/keywords/Blue_Hour.json"))
    #expect(collision.sources == ["keyword \"Blue Hour\"", "keyword \"Blue_Hour\""])

    let message = MuninError.keywordPathCollision(collisions: found).description
    #expect(message.contains("keywords/Blue_Hour.json"), "\(message)")
    #expect(message.contains("keyword \"Blue Hour\""), "\(message)")
    #expect(message.lowercased().contains("retag"), "message must say what to do: \(message)")

    // Nothing was written: the output root is still empty.
    let written = try FileManager.default.contentsOfDirectory(atPath: harness.outputRoot)
    #expect(written == [], "a rejected build wrote \(written)")
  }

  /// The other half of that contract: keywords that do *not* collide must
  /// still build, including the spliced-metadata path the test above uses
  /// (or it would prove only that the splice broke something).
  @Test func distinctKeywordsFromRealMetadataBuild() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }
    let donor = fixture.originPhoto("Misc/20180510-171752-IMG_7165.jpg")
    try fixture.addPhoto(
      toAlbum: "Tagged", fromSourceFile: donor, as: "one.jpg",
      iptcKeywords: ["Blue Hour", "Nightfall"])
    try fixture.addPhoto(
      toAlbum: "Tagged", fromSourceFile: fixture.originPhoto("Misc/portrait_mm.jpeg"),
      as: "two.jpg", iptcKeywords: ["Golden Hour", "Nightfall"])

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }

    try await harness.build()

    let pages = try FileManager.default.contentsOfDirectory(
      atPath: harness.outputRoot + "/keywords")
    #expect(pages.contains("Blue_Hour.json"), "\(pages.sorted())")
    #expect(pages.contains("Golden_Hour.json"), "\(pages.sorted())")
    #expect(pages.contains("Nightfall.json"), "\(pages.sorted())")
  }

  /// The cross-bucket case end to end, so the hand-built-`Album` test
  /// above is not the only evidence that a keyword and a person can
  /// contend for one page. `people` in the config is what splits the
  /// bucket — `applyConfigDerivedFields` re-splits every photo's tags
  /// against it — so naming `Blue_Hour` there makes the two spellings
  /// land one per bucket, which is the only way this state is reachable
  /// from a real gallery.
  @Test func aKeywordAndAPersonCollideThroughGalleryConfig() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }
    try fixture.addPhoto(
      toAlbum: "Tagged", fromSourceFile: fixture.originPhoto("Misc/20180510-171752-IMG_7165.jpg"),
      as: "one.jpg", iptcKeywords: ["Blue Hour", "Nightfall"])
    try fixture.addPhoto(
      toAlbum: "Tagged", fromSourceFile: fixture.originPhoto("Misc/portrait_mm.jpeg"),
      as: "two.jpg", iptcKeywords: ["Blue_Hour", "Nightfall"])

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, people: ["Blue_Hour"])
    defer { harness.cleanup() }

    let found = await keywordCollisions(from: harness)
    #expect(found.count == 1, "expected exactly one collision, got \(found)")
    let collision = try #require(found.first)
    #expect(collision.outputPath.hasSuffix("/keywords/Blue_Hour.json"))
    #expect(
      collision.sources == ["keyword \"Blue Hour\"", "person \"Blue_Hour\""],
      "the report must say which bucket each name came from: \(collision.sources)")
  }

  // MARK: - Reporting and blast radius

  /// A user with a large library needs the full list, not the first hit
  /// followed by another failed build for the next one — and the same list
  /// in the same order on every run of the same failing build.
  ///
  /// All five collisions sit in *one* album on purpose. The claims for a
  /// directory are accumulated in a `Dictionary` and iterated, so their
  /// natural order is the per-process randomised hash seed's; spreading
  /// them over several albums would let the (already sorted) directory
  /// walk supply the order and the sortedness assertion would hold no
  /// matter what `findOutputPathCollisions` did. Five rather than two so
  /// an unsorted implementation has a 1-in-120 chance of passing by luck
  /// rather than 1-in-2. Stems collide by extension rather than by case so
  /// this also runs on case-insensitive filesystems.
  @Test func everyCollisionIsReportedNotJustTheFirst() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }
    let stems = ["delta", "alpha", "echo", "bravo", "charlie"]
    for stem in stems {
      try fixture.addPhoto(toAlbum: "A", fromSourceFile: jpeg(fixture), as: "\(stem).jpg")
      try fixture.addPhoto(toAlbum: "A", fromSourceFile: jpeg2(fixture), as: "\(stem).jpeg")
    }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }

    let found = await collisions(from: harness)
    #expect(found.count == stems.count, "expected every collision, got \(found)")
    // Deterministically ordered so the message does not shuffle between
    // runs of the same failing build.
    #expect(
      found.map { $0.outputPath } == found.map { $0.outputPath }.sorted(),
      "collisions must be reported in a stable order: \(found.map { $0.outputPath })")
  }

  /// The check must run before anything is written, so a rejected build
  /// leaves the previously-generated gallery exactly as it was.
  @Test func aRejectedBuildDoesNotTouchExistingOutput() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }
    try await harness.build()
    let before = try harness.snapshotOutput()

    // Now introduce a collision and rebuild into the same output root.
    try fixture.addPhoto(
      toAlbum: "Misc", fromSourceFile: jpeg2(fixture), as: "test_special_chars.jpeg")

    let found = await collisions(from: harness)
    #expect(!found.isEmpty)

    let after = try harness.snapshotOutput()
    let diff = before.diff(against: after)
    #expect(diff.added == [], "rejected build added files: \(diff.added)")
    #expect(diff.removed == [], "rejected build removed files: \(diff.removed)")
    #expect(diff.byteChanged == [], "rejected build rewrote files: \(diff.byteChanged)")
  }

  /// The message is the entire user interface for this failure: it has to
  /// name the output path, every source that wants it, and what to do.
  @Test func theErrorMessageNamesBothSourcesAndTheOutputPath() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }
    try fixture.addPhoto(toAlbum: "Coll", fromSourceFile: jpeg(fixture), as: "sample.jpg")
    try fixture.addPhoto(toAlbum: "Coll", fromSourceFile: jpeg2(fixture), as: "sample.jpeg")

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }

    let found = await collisions(from: harness)
    let message = MuninError.outputPathCollision(collisions: found).description
    #expect(message.contains("Coll/sample.json"), "\(message)")
    #expect(message.contains(fixture.sourceRoot + "/Coll/sample.jpg"), "\(message)")
    #expect(message.contains(fixture.sourceRoot + "/Coll/sample.jpeg"), "\(message)")
    #expect(message.lowercased().contains("rename"), "message must say what to do: \(message)")
  }

  // MARK: - Negative controls

  /// Byte-distinct but canonically-equivalent names (NFC vs NFD, which is
  /// what a macOS-synced tree hands you) are two different files on Linux
  /// and two different output paths. They must build, not trip the
  /// collision check.
  ///
  /// Skipped on a normalization-insensitive volume, where the two source
  /// files cannot both exist and the negative control would be a control
  /// over nothing.
  @Test(.enabled(if: SourceFixture.filesystemDistinguishesUnicodeNormalization))
  func canonicallyEquivalentNamesAreNotACollision() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }
    // "Håkon": precomposed U+00E5 vs decomposed a + U+030A.
    try fixture.addPhoto(toAlbum: "Uni", fromSourceFile: jpeg(fixture), as: "H\u{00e5}kon.jpg")
    try fixture.addPhoto(toAlbum: "Uni", fromSourceFile: jpeg2(fixture), as: "Ha\u{030a}kon.jpg")

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }

    try await harness.build()

    // Deliberately not via `FilesystemSnapshot`: it keys entries by Swift
    // `String`, whose equality is canonical, so the two spellings collapse
    // into one entry there and the assertion would pass vacuously. Compare
    // UTF-8 bytes, which is what the filesystem actually stores.
    let names = try FileManager.default.contentsOfDirectory(
      atPath: harness.outputGalleryRoot + "/Uni")
    let jsons = Set(names.filter { $0.hasSuffix("kon.json") }.map { Array($0.utf8) })
    #expect(
      jsons.count == 2,
      "both spellings must produce their own JSON, got \(names.sorted())")
  }

  /// The stock example gallery must keep building. This is the control
  /// that says the check rejects only genuinely broken input.
  @Test func theExampleGalleryHasNoCollisions() async throws {
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }

    _ = try await harness.load()
  }
}
