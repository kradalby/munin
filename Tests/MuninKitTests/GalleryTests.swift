import Foundation
import Testing

@testable import MuninKit

@Suite(.serialized)
struct GalleryTests {

  /// Tests don't mutate the source tree, so they can read it directly
  /// rather than staging a copy per test. Saves several seconds × six
  /// tests on the full example gallery.
  private static let albumPath = "example/album"

  /// Number of photo + album entries in the tracked `example/album` tree.
  /// Derived from disk so the assertions keep pace with fixture changes.
  private static let expectedCounts: (photos: Int, albums: Int) = {
    let fm = FileManager.default
    let extensions: Set<String> = ["jpg", "jpeg", "JPG", "JPEG"]
    let rootURL = URL(fileURLWithPath: albumPath)
    guard let enumerator = fm.enumerator(
      at: rootURL, includingPropertiesForKeys: [.isDirectoryKey])
    else { return (0, 0) }
    var photos = 0
    var albums = 0
    for case let url as URL in enumerator {
      let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
      if isDir {
        albums += 1
      } else if extensions.contains(url.pathExtension) {
        photos += 1
      }
    }
    return (photos, albums)
  }()

  /// Direct-child photo count for a given album, relative to
  /// ``albumPath``. Used by the missing-folder diff test to derive its
  /// "how many photos vanished" expectation from the tree.
  private static func photosInAlbum(_ relative: String) -> Int {
    let fm = FileManager.default
    let extensions: Set<String> = ["jpg", "jpeg", "JPG", "JPEG"]
    let absolute = albumPath + "/" + relative
    return (try? fm.contentsOfDirectory(atPath: absolute))?
      .filter { extensions.contains(URL(fileURLWithPath: $0).pathExtension) }
      .count ?? 0
  }

  private static func makeHarness() -> GalleryHarness {
    GalleryHarness(
      sourceRoot: FileManager.default.currentDirectoryPath + "/" + albumPath,
      name: "root",
      resolutions: [100, 200, 300],
      peopleFiles: [
        FileManager.default.currentDirectoryPath + "/example/people.json"
      ],
      jpegCompression: 0.1,
      concurrency: ProcessInfo.processInfo.processorCount)
  }

  @Test func readInputGalleryPopulatesInput() async throws {
    let harness = Self.makeHarness()
    defer { harness.cleanup() }

    let gallery = try await Gallery.load(ctx: harness.ctx)
    #expect(gallery.input.numberOfPhotos(travers: true) == Self.expectedCounts.photos)
    #expect(gallery.input.numberOfAlbums(travers: true) == Self.expectedCounts.albums)
    #expect(gallery.output == nil)
  }

  @Test func readInputOutputGallerySeesBuiltOutput() async throws {
    let harness = Self.makeHarness()
    defer { harness.cleanup() }

    let gallery = try await Gallery.load(ctx: harness.ctx)
    #expect(gallery.input.numberOfPhotos(travers: true) == Self.expectedCounts.photos)
    #expect(gallery.input.numberOfAlbums(travers: true) == Self.expectedCounts.albums)
    #expect(gallery.output == nil)

    try await gallery.build(ctx: harness.ctx, jsonOnly: false)

    let gallery2 = try await Gallery.load(ctx: harness.ctx)
    let output2 = try #require(gallery2.output)
    #expect(output2.numberOfPhotos(travers: true) == Self.expectedCounts.photos)
    #expect(output2.numberOfAlbums(travers: true) == Self.expectedCounts.albums)
  }

  @Test func diffGalleryNoDiffReturnsNilChangedContent() async throws {
    let harness = Self.makeHarness()
    defer { harness.cleanup() }

    let gallery = try await Gallery.load(ctx: harness.ctx)
    #expect(gallery.input.numberOfPhotos(travers: true) == Self.expectedCounts.photos)
    #expect(gallery.input.numberOfAlbums(travers: true) == Self.expectedCounts.albums)
    #expect(gallery.output == nil)

    try await gallery.build(ctx: harness.ctx, jsonOnly: false)

    let gallery2 = try await Gallery.load(ctx: harness.ctx)
    #expect(gallery2.changedContent == nil)
  }

  @Test func diffGalleryAddedAlbumDetectsMissingFolder() async throws {
    let harness = Self.makeHarness()
    defer { harness.cleanup() }

    // Alkmaar: deepest album, many photos. A dropped output folder here
    // exercises the diff's "whole album missing from output" path.
    let missingAlbumSource = "2018/2018-03-10 AlkmaarÆØÅæøå"
    let missingAlbumOutput = "2018/2018-03-10_AlkmaarÆØÅæøå"
    let missingPhotos = Self.photosInAlbum(missingAlbumSource)

    let gallery = try await Gallery.load(ctx: harness.ctx)
    #expect(gallery.input.numberOfPhotos(travers: true) == Self.expectedCounts.photos)
    #expect(gallery.input.numberOfAlbums(travers: true) == Self.expectedCounts.albums)
    #expect(gallery.output == nil)

    try await gallery.build(ctx: harness.ctx, jsonOnly: false)

    let fm = FileManager.default
    let deletePath = joinPath(harness.outputGalleryRoot, missingAlbumOutput)
    try fm.removeItem(atPath: deletePath)

    let gallery2 = try await Gallery.load(ctx: harness.ctx)
    #expect(gallery2.input.numberOfPhotos(travers: true) == Self.expectedCounts.photos)
    #expect(gallery2.input.numberOfAlbums(travers: true) == Self.expectedCounts.albums)
    #expect(gallery2.output != nil)

    // Diff tree for the missing leaf keeps the ancestor chain: 2018 (1
    // child: Alkmaar) + Alkmaar itself = 2 albums. All Alkmaar's photos
    // surface as "changed".
    let changed = try #require(gallery2.changedContent)
    #expect(changed.numberOfPhotos(travers: true) == missingPhotos)
    #expect(changed.numberOfAlbums(travers: true) == 2)
  }

  @Test func diffGalleryAddedPhotosDetectsMissingFiles() async throws {
    let harness = Self.makeHarness()
    defer { harness.cleanup() }

    let gallery = try await Gallery.load(ctx: harness.ctx)
    #expect(gallery.input.numberOfPhotos(travers: true) == Self.expectedCounts.photos)
    #expect(gallery.input.numberOfAlbums(travers: true) == Self.expectedCounts.albums)
    #expect(gallery.output == nil)

    try await gallery.build(ctx: harness.ctx, jsonOnly: false)

    let fm = FileManager.default
    let photosToDelete = [
      "20180310-143656-IMG_6012.json",
      "20180310-144346-IMG_6013.json",
      "20180310-144514-IMG_6014.json",
      "20180310-144523-IMG_6015.json",
      "20180310-144631-IMG_6016.json",
      "20180310-150725-IMG_6017.json",
      "20180310-151102-IMG_6018.json",
      "20180310-151205-IMG_6019.json",
    ]
    for photo in photosToDelete {
      let deletePath = joinPath(
        harness.outputGalleryRoot, "2018/2018-03-10_AlkmaarÆØÅæøå", photo)
      try fm.removeItem(atPath: deletePath)
    }

    let gallery2 = try await Gallery.load(ctx: harness.ctx)
    #expect(gallery2.input.numberOfPhotos(travers: true) == Self.expectedCounts.photos)
    #expect(gallery2.input.numberOfAlbums(travers: true) == Self.expectedCounts.albums)
    #expect(gallery2.output != nil)

    let changed = try #require(gallery2.changedContent)
    #expect(changed.numberOfPhotos(travers: true) == photosToDelete.count)
  }

  @Test func cleanRemovesUnreferencedOutput() async throws {
    let harness = Self.makeHarness()
    defer { harness.cleanup() }

    // Photo/album counts when the "2018" top-level branch is pruned from
    // input. Derive from the tree so this stays honest as fixtures change.
    let prunedPhotos = Self.expectedCounts.photos - Self.photoCountUnder("2018")
    let prunedAlbums = Self.expectedCounts.albums - Self.albumCountUnder("2018") - 1

    let gallery = try await Gallery.load(ctx: harness.ctx)
    #expect(gallery.input.numberOfPhotos(travers: true) == Self.expectedCounts.photos)
    #expect(gallery.input.numberOfAlbums(travers: true) == Self.expectedCounts.albums)
    #expect(gallery.output == nil)

    try await gallery.build(ctx: harness.ctx, jsonOnly: false)

    // Output, empty, does nothing
    gallery.clean(ctx: harness.ctx)

    var gallery2 = try await Gallery.load(ctx: harness.ctx)
    #expect(gallery2.input.numberOfPhotos(travers: true) == Self.expectedCounts.photos)
    #expect(gallery2.input.numberOfAlbums(travers: true) == Self.expectedCounts.albums)
    let output2 = try #require(gallery2.output)
    #expect(output2.numberOfPhotos(travers: true) == Self.expectedCounts.photos)
    #expect(output2.numberOfAlbums(travers: true) == Self.expectedCounts.albums)

    var albums = Array(gallery2.input.albums)
    albums.removeAll(where: { $0.name == "2018" })
    var input = gallery2.input
    input.albums = Set(albums)
    gallery2.setInput(input)
    #expect(gallery2.input.numberOfPhotos(travers: true) == prunedPhotos)
    #expect(gallery2.input.numberOfAlbums(travers: true) == prunedAlbums)
    let output2After = try #require(gallery2.output)
    #expect(output2After.numberOfPhotos(travers: true) == Self.expectedCounts.photos)
    #expect(output2After.numberOfAlbums(travers: true) == Self.expectedCounts.albums)

    gallery2.clean(ctx: harness.ctx)

    let gallery3 = try await Gallery.load(ctx: harness.ctx)
    #expect(gallery3.input.numberOfPhotos(travers: true) == Self.expectedCounts.photos)
    #expect(gallery3.input.numberOfAlbums(travers: true) == Self.expectedCounts.albums)
    let output3 = try #require(gallery3.output)
    #expect(output3.numberOfPhotos(travers: true) == prunedPhotos)
    #expect(output3.numberOfAlbums(travers: true) == prunedAlbums)
  }

  private static func photoCountUnder(_ relative: String) -> Int {
    let fm = FileManager.default
    let extensions: Set<String> = ["jpg", "jpeg", "JPG", "JPEG"]
    let rootURL = URL(fileURLWithPath: albumPath + "/" + relative)
    guard let enumerator = fm.enumerator(at: rootURL, includingPropertiesForKeys: nil)
    else { return 0 }
    var count = 0
    for case let url as URL in enumerator where extensions.contains(url.pathExtension) {
      count += 1
    }
    return count
  }

  private static func albumCountUnder(_ relative: String) -> Int {
    let fm = FileManager.default
    let rootURL = URL(fileURLWithPath: albumPath + "/" + relative)
    guard let enumerator = fm.enumerator(
      at: rootURL, includingPropertiesForKeys: [.isDirectoryKey])
    else { return 0 }
    var count = 0
    for case let url as URL in enumerator {
      let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
      if isDir { count += 1 }
    }
    return count
  }
}
