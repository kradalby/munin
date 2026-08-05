import Foundation
import Testing

@testable import MuninKit

/// Locks the *values* of the URLs Munin publishes, which neither
/// `ApiContractTests` (which locks keys) nor `OutputShapeTests` (which locks
/// the on-disk tree) covers.
///
/// Munin built the published URL and the path it writes to from one string,
/// so every emitted URL carried `Configuration.targetFolder`. A consumer had
/// to hard-code that same directory name to resolve anything, and when the
/// target folder was absolute — as it is under the test harness — the JSON
/// leaked machine-specific absolute paths.
///
/// These tests assert the published form directly from the JSON on disk,
/// rather than through the model, so they would catch the model and the
/// encoder drifting apart.
@Suite(.serialized)
struct PublishedURLTests {

  /// Every string in the decoded JSON reachable under a `url`-ish key.
  ///
  /// `next`/`previous` are in the set because they are urls too, spelled
  /// without the word: they point at sibling photo JSON and a consumer
  /// resolves them exactly like `url`.
  private func publishedURLs(
    in object: Any,
    keys: Set<String> = ["url", "originalImageURL", "next", "previous"]
  ) -> [String] {
    switch object {
    case let dictionary as [String: Any]:
      return dictionary.flatMap { key, value -> [String] in
        if keys.contains(key), let string = value as? String {
          return [string]
        }
        return publishedURLs(in: value, keys: keys)
      }
    case let array as [Any]:
      return array.flatMap { publishedURLs(in: $0, keys: keys) }
    default:
      return []
    }
  }

  /// The contract in one assertion: a published URL is relative, leaks
  /// nothing about where Munin wrote, and resolves to a real file once
  /// joined to wherever the gallery is served from.
  private func expectResolvable(
    _ url: String, under galleryRoot: String,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    #expect(
      !url.hasPrefix("/"),
      "published URL is absolute, so it cannot be resolved against a web root: \(url)",
      sourceLocation: sourceLocation)
    #expect(
      !url.contains(galleryRoot),
      "published URL leaks the output directory: \(url)",
      sourceLocation: sourceLocation)
    #expect(
      FileManager.default.fileExists(atPath: "\(galleryRoot)/\(url)"),
      "published URL does not resolve under the gallery root: \(url)",
      sourceLocation: sourceLocation)
  }

  /// Photos live in sub-albums, so the top-level album usually has none.
  private func firstPhoto(in album: Album) -> Photo? {
    if let photo = album.photos.sorted().first { return photo }
    for child in album.albums.sorted() {
      if let photo = firstPhoto(in: child) { return photo }
    }
    return nil
  }

  private func json(at path: String) throws -> Any {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONSerialization.jsonObject(with: data)
  }

  @Test func publishedURLsAreRelativeToTheGalleryRoot() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.build()

    let index = try json(at: "\(harness.outputRoot)/root/index.json")
    let urls = publishedURLs(in: index)

    #expect(!urls.isEmpty, "album index published no URLs")

    for url in urls {
      expectResolvable(url, under: harness.outputRoot)
    }
  }

  @Test func photoJSONPublishesRelativeURLs() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    let gallery = try await harness.build()

    let photo = try #require(firstPhoto(in: gallery.input), "fixture produced no photos")

    // The model still carries the full on-disk path: writers, symlink depth
    // and cleanup all depend on it.
    #expect(photo.url.string.hasPrefix(harness.outputRoot))

    let published = try json(at: photo.url.string)
    let urls = publishedURLs(in: published)

    #expect(!urls.isEmpty, "photo JSON published no URLs")

    for url in urls {
      expectResolvable(url, under: harness.outputRoot)
    }
  }

  /// Scaled photo URLs are what an `img srcset` is built from, so they get
  /// their own assertion rather than riding on the recursive walk.
  @Test func scaledPhotoURLsAreRelative() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    let gallery = try await harness.build()

    let photo = try #require(firstPhoto(in: gallery.input), "fixture produced no photos")
    let published = try #require(
      try json(at: photo.url.string) as? [String: Any], "photo JSON is not an object")
    let scaled = try #require(
      published["scaledPhotos"] as? [[String: Any]], "photo JSON has no scaledPhotos")

    #expect(!scaled.isEmpty, "photo published no scaled resolutions")

    for entry in scaled {
      let url = try #require(entry["url"] as? String, "scaledPhotos entry has no url")
      #expect(!url.hasSuffix(".json"), "scaled photo URL should point at an image: \(url)")
      expectResolvable(url, under: harness.outputRoot)
    }
  }

  @Test func locationsJSONPublishesRelativeURLs() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.build()

    let path = "\(harness.outputRoot)/root/locations.json"
    guard FileManager.default.fileExists(atPath: path) else { return }

    for url in publishedURLs(in: try json(at: path)) {
      expectResolvable(url, under: harness.outputRoot)
    }
  }

  /// The incremental rebuild reads the previous output back. If decoding did
  /// not restore the gallery root, those paths would no longer resolve and
  /// every photo would look missing.
  @Test func readingOutputBackRestoresUsablePaths() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "root")
    defer { harness.cleanup() }
    try await harness.build()

    let album = try #require(
      readStateFromOutputDirectory(
        indexFileAtPath: "\(harness.outputRoot)/root/index.json",
        galleryRoot: harness.outputRoot),
      "output directory could not be read back")

    #expect(album.url.string.hasPrefix(harness.outputRoot))
    #expect(FileManager.default.fileExists(atPath: album.url.string))

    for photo in album.photos {
      #expect(
        FileManager.default.fileExists(atPath: photo.url.string),
        "photo path did not survive the round trip: \(photo.url.string)")
    }
  }
}
