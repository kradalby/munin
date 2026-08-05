import Foundation
import Testing

@testable import MuninKit

/// An album's own output directory is `urlifyName(name)` — spaces become
/// underscores — but the output root handed to its children was the raw,
/// un-urlified name. For any album whose name contains a space that put
/// the album's `index.json` in one directory and every one of its
/// sub-albums in a *different* one, which the parent album then deleted as
/// unreferenced. Album names with spaces are ordinary (`example/album` is
/// full of them); nesting under one lost every photo below it.
@Suite(.serialized)
struct NestedAlbumPathTests {

  @Test func subAlbumsOfASpacedAlbumLiveUnderItsOwnDirectory() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }
    try fixture.addPhoto(
      toAlbum: "My Album",
      fromSourceFile: fixture.originPhoto("Misc/test_special_chars.jpg"),
      as: "top.jpg")
    try fixture.addPhoto(
      toAlbum: "My Album/Nested",
      fromSourceFile: fixture.originPhoto("Misc/portrait_mm.jpeg"),
      as: "deep.jpeg")

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }
    try await harness.buildAndClean()

    let snapshot = try harness.snapshotOutput()
    let paths = Set(snapshot.leafPaths)

    #expect(
      paths.contains("root/My_Album/Nested/deep.json"),
      "nested album must be written under its parent's own directory; got \(paths.sorted())")
    #expect(
      !paths.contains(where: { $0.contains("My Album") }),
      "nothing may be written to the un-urlified path: \(paths.sorted())")
  }

  /// The parent's `albums` entry has to point at where the sub-album was
  /// actually written, otherwise the gallery links into nothing.
  @Test func parentAlbumLinksToTheDirectoryItsChildWasWrittenTo() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }
    try fixture.addPhoto(
      toAlbum: "My Album",
      fromSourceFile: fixture.originPhoto("Misc/test_special_chars.jpg"),
      as: "top.jpg")
    try fixture.addPhoto(
      toAlbum: "My Album/Nested",
      fromSourceFile: fixture.originPhoto("Misc/portrait_mm.jpeg"),
      as: "deep.jpeg")

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }
    try await harness.buildAndClean()

    let indexPath = harness.outputGalleryRoot + "/My_Album/index.json"
    let data = try Data(contentsOf: URL(fileURLWithPath: indexPath))
    let object = try #require(
      try JSONSerialization.jsonObject(with: data) as? [String: Any])
    let albums = try #require(object["albums"] as? [[String: Any]])
    let urls = albums.compactMap { $0["url"] as? String }
    #expect(urls.count == 1, "expected one sub-album entry, got \(urls)")

    for url in urls {
      // Published urls are relative to the gallery root, which the
      // harness puts at `outputRoot`.
      let path = url.hasPrefix("/") ? url : harness.outputRoot + "/" + url
      #expect(
        FileManager.default.fileExists(atPath: path),
        "album index points at a path that was never written: \(url)")
    }
  }

  /// `clean` walks the real directory tree; anything written outside the
  /// album's declared path looks unreferenced to its parent and is
  /// deleted. This is the assertion that the photo actually survives a
  /// full load → build → clean cycle.
  @Test func nestedPhotoSurvivesClean() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }
    try fixture.addPhoto(
      toAlbum: "My Album",
      fromSourceFile: fixture.originPhoto("Misc/test_special_chars.jpg"),
      as: "top.jpg")
    try fixture.addPhoto(
      toAlbum: "My Album/Nested",
      fromSourceFile: fixture.originPhoto("Misc/portrait_mm.jpeg"),
      as: "deep.jpeg")

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }
    try await harness.buildAndClean()

    let snapshot = try harness.snapshotOutput()
    let nested = snapshot.leafPaths.filter { $0.contains("Nested/") }
    #expect(
      nested.contains("root/My_Album/Nested/deep.json"),
      "nested photo JSON was deleted by clean: \(nested)")
    #expect(
      nested.contains("root/My_Album/Nested/deep_original.jpeg"),
      "nested photo original symlink was deleted by clean: \(nested)")
  }
}
