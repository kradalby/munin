import Foundation
import Testing

@testable import MuninKit

/// The gallery at core.tjoda held `keywords/Aspargesgården.json` twice —
/// `…6761 cc8a 7264656e` and `…6767 c3a5 7264656e` — because one photo's IPTC
/// block carried both spellings. Swift `String` calls them equal, ext4 does
/// not, so munin wrote one file and published two URLs.
@Suite(.serialized)
struct KeywordNormalizationTests {

  /// Written as escapes, never as literal text: the two spellings render
  /// identically, so an editor that normalises on save would silently gut
  /// every assertion below.
  private static let decomposed = "Aspargesga\u{030A}rden"  // a + combining ring
  private static let composed = "Aspargesg\u{00E5}rden"  // precomposed å
  private static let expectedURL = "out/keywords/Aspargesg\u{00E5}rden.json"

  @Test func bothSpellingsProduceOneIdenticalPointer() {
    let fromNFD = KeywordPointer(keyword: Self.decomposed, outputPath: "out")
    let fromNFC = KeywordPointer(keyword: Self.composed, outputPath: "out")

    // Byte equality, not Swift's canonical `==`, is the property that matters:
    // these strings become filenames.
    #expect(Array(fromNFD.url.string.utf8) == Array(fromNFC.url.string.utf8))
    #expect(Array(fromNFD.name.utf8) == Array(fromNFC.name.utf8))
    #expect(fromNFD.url.string == Self.expectedURL)
  }

  @Test func aPhotoCarryingBothSpellingsTagsItOnce() {
    var photo = Photo(name: "p", dateTime: nil)
    photo.keywords = [
      KeywordPointer(keyword: Self.decomposed, outputPath: "out"),
      KeywordPointer(keyword: Self.composed, outputPath: "out"),
    ]

    // `buildKeywordsFromAlbum` keys on the Swift String, so it always
    // collapsed the pair; what it could not do was pick a stable URL.
    var album = Album(name: "a", path: "out", parents: [])
    album.photos.insert(photo)
    let keywords = buildKeywordsFromAlbum(album: album)

    #expect(keywords.count == 1)
    #expect(keywords[0].url.string == Self.expectedURL)
  }

  /// `Album.clean` walks album folders only, so before this nothing had ever
  /// swept `keywords/`. On the live gallery that left
  /// `keywords/Aspargesga\u{030A}rden.json` sitting next to its NFC twin for
  /// three weeks and a full 26h rebuild, still serving the pre-fix
  /// `hugin/root/...` paths it was written with. That is the migration story
  /// for the fossils already on disk: no host-side rename to remember.
  @Test func cleanRemovesKeywordFilesNothingPointsAt() async throws {
    // The whole tree, not one album: the sweep is only meaningful against a
    // keywords directory that has something real in it to spare.
    let fixture = try SourceFixture.stageAll()
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }

    try await harness.buildAndClean()

    let keywordsDir = harness.outputRoot + "/keywords"
    let fm = FileManager.default
    let expected = Set(try fm.contentsOfDirectory(atPath: keywordsDir))
    #expect(!expected.isEmpty)

    let orphan = keywordsDir + "/" + Self.decomposed + ".json"
    #expect(fm.createFile(atPath: orphan, contents: Data("{}".utf8)))

    try await harness.buildAndClean()

    // The orphan is gone and nothing real went with it.
    #expect(Set(try fm.contentsOfDirectory(atPath: keywordsDir)) == expected)
  }
}
