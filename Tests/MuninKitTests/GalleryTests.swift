import Foundation
import Testing

@testable import MuninKit

@Suite(.serialized)
final class GalleryTests {
  let albumPath = "example/album/"
  let peoplePath = "example/people.json"
  let testName: String
  let testDirectoryPath: String
  let config: GalleryConfiguration
  let ctx: Context

  init() throws {
    VIPSSetup.ensure()
    let fm = FileManager.default
    testName = randomString(length: 10)
    testDirectoryPath = joinPath(fm.temporaryDirectory.path, testName)
    try fm.createDirectory(
      atPath: testDirectoryPath, withIntermediateDirectories: true)

    let manager = ConfigurationManager()
    manager.load([
      "name": testName,
      "people": [],
      "peopleFiles": [peoplePath],
      "resolutions": [100, 200, 300],
      "jpegCompression": 0.1,
      "sourceFolder": albumPath,
      "targetFolder": testDirectoryPath,
      "fileExtensions": ["jpg", "jpeg", "JPG", "JPEG"],
      "diff": false,
      "progress": false,
    ])
    self.config = GalleryConfiguration(manager)
    self.ctx = Context(config: config)
  }

  deinit {
    // Best-effort cleanup; the OS will reclaim /tmp anyway.
    try? FileManager.default.removeItem(atPath: testDirectoryPath)
  }

  @Test func readInputGalleryPopulatesInput() async throws {
    let gallery = try await Gallery.load(ctx: ctx)
    #expect(gallery.input.numberOfPhotos(travers: true) == 104)
    #expect(gallery.input.numberOfAlbums(travers: true) == 12)
    #expect(gallery.output == nil)
  }

  @Test func readInputOutputGallerySeesBuiltOutput() async throws {
    let gallery = try await Gallery.load(ctx: ctx)
    #expect(gallery.input.numberOfPhotos(travers: true) == 104)
    #expect(gallery.input.numberOfAlbums(travers: true) == 12)
    #expect(gallery.output == nil)

    try await gallery.build(ctx: ctx, jsonOnly: false)

    let gallery2 = try await Gallery.load(ctx: ctx)
    let output2 = try #require(gallery2.output)
    #expect(output2.numberOfPhotos(travers: true) == 104)
    #expect(output2.numberOfAlbums(travers: true) == 12)
  }

  @Test func diffGalleryNoDiffReturnsNilChangedContent() async throws {
    let gallery = try await Gallery.load(ctx: ctx)
    #expect(gallery.input.numberOfPhotos(travers: true) == 104)
    #expect(gallery.input.numberOfAlbums(travers: true) == 12)
    #expect(gallery.output == nil)

    try await gallery.build(ctx: ctx, jsonOnly: false)

    let gallery2 = try await Gallery.load(ctx: ctx)
    #expect(gallery2.changedContent == nil)
  }

  @Test func diffGalleryAddedAlbumDetectsMissingFolder() async throws {
    let gallery = try await Gallery.load(ctx: ctx)
    #expect(gallery.input.numberOfPhotos(travers: true) == 104)
    #expect(gallery.input.numberOfAlbums(travers: true) == 12)
    #expect(gallery.output == nil)

    try await gallery.build(ctx: ctx, jsonOnly: false)

    let fm = FileManager.default
    let deletePath = joinPath(
      testDirectoryPath, testName, "2018", "2018-03-10_AlkmaarÆØÅæøå")
    try fm.removeItem(atPath: deletePath)

    let gallery2 = try await Gallery.load(ctx: ctx)
    #expect(gallery2.input.numberOfPhotos(travers: true) == 104)
    #expect(gallery2.input.numberOfAlbums(travers: true) == 12)
    #expect(gallery2.output != nil)

    let changed = try #require(gallery2.changedContent)
    #expect(changed.numberOfPhotos(travers: true) > 0)
    #expect(changed.numberOfAlbums(travers: true) > 0)
  }

  @Test func diffGalleryAddedPhotosDetectsMissingFiles() async throws {
    let gallery = try await Gallery.load(ctx: ctx)
    #expect(gallery.input.numberOfPhotos(travers: true) == 104)
    #expect(gallery.input.numberOfAlbums(travers: true) == 12)
    #expect(gallery.output == nil)

    try await gallery.build(ctx: ctx, jsonOnly: false)

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
        testDirectoryPath, testName, "2018", "2018-03-10_AlkmaarÆØÅæøå", photo)
      try fm.removeItem(atPath: deletePath)
    }

    let gallery2 = try await Gallery.load(ctx: ctx)
    #expect(gallery2.input.numberOfPhotos(travers: true) == 104)
    #expect(gallery2.input.numberOfAlbums(travers: true) == 12)
    #expect(gallery2.output != nil)

    let changed = try #require(gallery2.changedContent)
    #expect(changed.numberOfPhotos(travers: true) == photosToDelete.count)
  }

  @Test func cleanRemovesUnreferencedOutput() async throws {
    let gallery = try await Gallery.load(ctx: ctx)
    #expect(gallery.input.numberOfPhotos(travers: true) == 104)
    #expect(gallery.input.numberOfAlbums(travers: true) == 12)
    #expect(gallery.output == nil)

    try await gallery.build(ctx: ctx, jsonOnly: false)

    // Output, empty, does nothing
    gallery.clean(ctx: ctx)

    var gallery2 = try await Gallery.load(ctx: ctx)
    #expect(gallery2.input.numberOfPhotos(travers: true) == 104)
    #expect(gallery2.input.numberOfAlbums(travers: true) == 12)
    let output2 = try #require(gallery2.output)
    #expect(output2.numberOfPhotos(travers: true) == 104)
    #expect(output2.numberOfAlbums(travers: true) == 12)

    var albums = Array(gallery2.input.albums)
    albums.removeAll(where: { $0.name == "2018" })
    var input = gallery2.input
    input.albums = Set(albums)
    gallery2.setInput(input)
    #expect(gallery2.input.numberOfPhotos(travers: true) == 24)
    #expect(gallery2.input.numberOfAlbums(travers: true) == 7)
    let output2After = try #require(gallery2.output)
    #expect(output2After.numberOfPhotos(travers: true) == 104)
    #expect(output2After.numberOfAlbums(travers: true) == 12)

    gallery2.clean(ctx: ctx)

    let gallery3 = try await Gallery.load(ctx: ctx)
    #expect(gallery3.input.numberOfPhotos(travers: true) == 104)
    #expect(gallery3.input.numberOfAlbums(travers: true) == 12)
    let output3 = try #require(gallery3.output)
    #expect(output3.numberOfPhotos(travers: true) == 24)
    #expect(output3.numberOfAlbums(travers: true) == 7)
  }
}
