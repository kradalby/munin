import Foundation
import SystemPackage
import Testing

@testable import MuninKit

/// ``GalleryURL`` is the seam between what Munin writes to disk and what it
/// publishes. These tests pin both halves: the in-memory value stays a usable
/// on-disk path, while the encoded value is relative to the gallery root.
@Suite
struct GalleryURLTests {

  private struct Holder: Codable, Equatable {
    var url: GalleryURL
  }

  private func encode(_ value: Holder, galleryRoot: String) throws -> String {
    let data = try MuninJSON.encoder(galleryRoot: galleryRoot).encode(value)
    return String(decoding: data, as: UTF8.self)
  }

  private func decode(_ json: String, galleryRoot: String) throws -> Holder {
    try MuninJSON.decoder(galleryRoot: galleryRoot)
      .decode(Holder.self, from: Data(json.utf8))
  }

  // MARK: - Encoding

  @Test func encodingStripsTheGalleryRoot() throws {
    let holder = Holder(url: GalleryURL("hugin/root/2001/index.json"))
    #expect(try encode(holder, galleryRoot: "hugin") == #"{"url":"root/2001/index.json"}"#)
  }

  /// The whole point of the change: the published value must not depend on
  /// what the output directory happens to be called.
  @Test func encodedValueIsIndependentOfTheRootName() throws {
    let underHugin = Holder(url: GalleryURL("hugin/root/a.json"))
    let underContent = Holder(url: GalleryURL("content/root/a.json"))

    #expect(
      try encode(underHugin, galleryRoot: "hugin")
        == encode(underContent, galleryRoot: "content"))
  }

  @Test func encodingWithoutARootLeavesThePathAlone() throws {
    let holder = Holder(url: GalleryURL("hugin/root/a.json"))
    #expect(try encode(holder, galleryRoot: "") == #"{"url":"hugin/root/a.json"}"#)
  }

  @Test func encodingLeavesPathsOutsideTheRootAlone() throws {
    let holder = Holder(url: GalleryURL("elsewhere/root/a.json"))
    #expect(try encode(holder, galleryRoot: "hugin") == #"{"url":"elsewhere/root/a.json"}"#)
  }

  @Test func encodingDoesNotEscapeSlashes() throws {
    let json = try encode(Holder(url: GalleryURL("hugin/root/a.json")), galleryRoot: "hugin")
    #expect(!json.contains(#"\/"#))
  }

  // MARK: - Decoding

  @Test func decodingRestoresTheGalleryRoot() throws {
    let holder = try decode(#"{"url":"root/2001/index.json"}"#, galleryRoot: "hugin")
    #expect(holder.url.path == FilePath("hugin/root/2001/index.json"))
  }

  @Test func decodingWithoutARootKeepsTheValueVerbatim() throws {
    let holder = try decode(#"{"url":"root/2001/index.json"}"#, galleryRoot: "")
    #expect(holder.url.path == FilePath("root/2001/index.json"))
  }

  // MARK: - Round-trip

  @Test func roundTripThroughTheGalleryRootIsLossless() throws {
    let original = Holder(url: GalleryURL("hugin/root/2001/2001-01-12_340.jpeg"))
    let json = try encode(original, galleryRoot: "hugin")
    #expect(try decode(json, galleryRoot: "hugin") == original)
  }

  /// Reading back a gallery that was written under a different output
  /// directory name must still yield paths rooted where Munin writes now.
  @Test func roundTripAcrossARenamedRootRerootsToTheCurrentGallery() throws {
    let json = try encode(Holder(url: GalleryURL("content/root/a.json")), galleryRoot: "content")
    let reread = try decode(json, galleryRoot: "hugin")
    #expect(reread.url.path == FilePath("hugin/root/a.json"))
  }

  @Test func roundTripPreservesNonASCIIComponents() throws {
    let original = Holder(url: GalleryURL("hugin/root/2024/Håkon_har_nytt_/a.json"))
    let json = try encode(original, galleryRoot: "hugin")
    #expect(try decode(json, galleryRoot: "hugin") == original)
  }

  // MARK: - Value semantics

  @Test func comparableOrdersByPath() {
    #expect(GalleryURL("a/b.json") < GalleryURL("a/c.json"))
    #expect(!(GalleryURL("a/c.json") < GalleryURL("a/b.json")))
  }

  @Test func equalPathsAreEqualAndHashAlike() {
    let a = GalleryURL("hugin/root/a.json")
    let b = GalleryURL(FilePath("hugin/root/a.json"))
    #expect(a == b)
    #expect(a.hashValue == b.hashValue)
  }
}
