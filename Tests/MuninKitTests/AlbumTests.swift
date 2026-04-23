import Foundation
import Testing

@testable import MuninKit

@Suite(.serialized)
final class AlbumTests {
  let albumPath = "example/album/"
  let outPath = "example/content/"
  let configPath = "example/munin.json"
  let config: GalleryConfiguration
  let ctx: Context

  init() {
    VIPSSetup.ensure()
    let manager = ConfigurationManager()
    manager
      .load(file: configPath, relativeFrom: .customPath(""))
      .load(["progress": false])
    self.config = GalleryConfiguration(manager)
    self.ctx = Context(config: config)
  }

  @Test func readStateFromInputDirectoryReturnsExpectedCounts() async throws {
    let album = try await readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath, outPath: outPath, name: "test", parents: [])

    #expect(album.numberOfPhotos(travers: true) == 104)
    #expect(album.numberOfAlbums(travers: true) == 12)
  }

  @Test func expectedFilesMatchAcrossAlbumTree() async throws {
    let album = try await readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath + "/Misc", outPath: outPath, name: "test",
      parents: [Parent(name: "", url: "")])

    #expect(album.numberOfPhotos(travers: true) == 3)
    #expect(album.numberOfAlbums(travers: true) == 0)

    let cwd = FileManager.default.currentDirectoryPath
    let contentDir = "\(cwd)/example/content"
    let expectedFiles = [
      "\(contentDir)/test/20180510-171752-IMG_7165.json",
      "\(contentDir)/test/20180510-171752-IMG_7165_180.jpg",
      "\(contentDir)/test/20180510-171752-IMG_7165_220.jpg",
      "\(contentDir)/test/20180510-171752-IMG_7165_340.jpg",
      "\(contentDir)/test/20180510-171752-IMG_7165_576.jpg",
      "\(contentDir)/test/20180510-171752-IMG_7165_original.jpg",
      "\(contentDir)/test/index.json",
      "\(contentDir)/test/test_special_chars.json",
      "\(contentDir)/test/test_special_chars_180.jpg",
      "\(contentDir)/test/test_special_chars_220.jpg",
      "\(contentDir)/test/test_special_chars_original.jpg",
      "\(contentDir)/test/portrait_mm.json",
      "\(contentDir)/test/portrait_mm_180.jpeg",
      "\(contentDir)/test/portrait_mm_220.jpeg",
      "\(contentDir)/test/portrait_mm_340.jpeg",
      "\(contentDir)/test/portrait_mm_576.jpeg",
      "\(contentDir)/test/portrait_mm_768.jpeg",
      "\(contentDir)/test/portrait_mm_992.jpeg",
      "\(contentDir)/test/portrait_mm_1200.jpeg",
      "\(contentDir)/test/portrait_mm_1600.jpeg",
      "\(contentDir)/test/portrait_mm_original.jpeg",
    ].sorted()
    let actualFiles = album.expectedFiles.map { $0.path }.sorted()
    #expect(actualFiles == expectedFiles)
  }

  @Test func unreferencedFilesEmptyWithoutOutputDirectory() async throws {
    let album = try await readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath + "/Misc", outPath: outPath, name: "test",
      parents: [Parent(name: "", url: "")])

    #expect(album.numberOfPhotos(travers: true) == 3)
    #expect(album.numberOfAlbums(travers: true) == 0)
    #expect(album.unreferencedFiles == [])
  }

  @Test func unreferencedFilesWithOutputDirectory() async throws {
    let album = try await readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath, outPath: outPath, name: "root", parents: [])

    #expect(album.numberOfPhotos(travers: true) == 104)
    #expect(album.numberOfAlbums(travers: true) == 12)
    #expect(album.unreferencedFiles == [])
  }

  @Test func missingFilesReportedWhenOutputIsEmpty() async throws {
    let album = try await readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath + "/Misc", outPath: outPath, name: "test",
      parents: [Parent(name: "", url: "")])

    #expect(album.numberOfPhotos(travers: true) == 3)
    #expect(album.numberOfAlbums(travers: true) == 0)

    let cwd = FileManager.default.currentDirectoryPath
    let contentDir = "\(cwd)/example/content"
    let expectedFiles = [
      "\(contentDir)/test/20180510-171752-IMG_7165.json",
      "\(contentDir)/test/20180510-171752-IMG_7165_180.jpg",
      "\(contentDir)/test/20180510-171752-IMG_7165_220.jpg",
      "\(contentDir)/test/20180510-171752-IMG_7165_340.jpg",
      "\(contentDir)/test/20180510-171752-IMG_7165_576.jpg",
      "\(contentDir)/test/20180510-171752-IMG_7165_original.jpg",
      "\(contentDir)/test/index.json",
      "\(contentDir)/test/test_special_chars.json",
      "\(contentDir)/test/test_special_chars_180.jpg",
      "\(contentDir)/test/test_special_chars_220.jpg",
      "\(contentDir)/test/test_special_chars_original.jpg",
      "\(contentDir)/test/portrait_mm.json",
      "\(contentDir)/test/portrait_mm_180.jpeg",
      "\(contentDir)/test/portrait_mm_220.jpeg",
      "\(contentDir)/test/portrait_mm_340.jpeg",
      "\(contentDir)/test/portrait_mm_576.jpeg",
      "\(contentDir)/test/portrait_mm_768.jpeg",
      "\(contentDir)/test/portrait_mm_992.jpeg",
      "\(contentDir)/test/portrait_mm_1200.jpeg",
      "\(contentDir)/test/portrait_mm_1600.jpeg",
      "\(contentDir)/test/portrait_mm_original.jpeg",
    ].sorted()
    let missing = album.missingFiles.map { $0.path }.sorted()
    #expect(missing == expectedFiles)
  }

  @Test func missingFilesEmptyWhenOutputExists() async throws {
    let album = try await readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath, outPath: outPath, name: "root", parents: [])

    #expect(album.numberOfPhotos(travers: true) == 104)
    #expect(album.numberOfAlbums(travers: true) == 12)
    #expect(album.missingFiles.map { $0.path }.sorted() == [])
  }

  @Test func changedPhotosDetectedViaSetDifference() {
    var input = Album(name: "root", path: "", parents: [])
    var current = Album(name: "root", path: "", parents: [])
    // Photo equality keys on sourceHash, not mtime. Use distinct hashes to
    // differentiate an "original" and "modified" version of the same file.
    var ph1 = Photo(
      name: "photo1", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [],
      modifiedDate: Date(timeIntervalSince1970: 1_610_472_000), parents: [])
    ph1.sourceHash = "hash-photo1-v1"
    let ph2 = Photo(name: "photo2")
    let ph3 = Photo(name: "photo3")
    let ph4 = Photo(name: "photo4")
    var ph1Modified = Photo(
      name: "photo1", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [],
      modifiedDate: Date(timeIntervalSince1970: 1_610_472_000), parents: [])
    ph1Modified.sourceHash = "hash-photo1-v2"

    input.photos = [ph1, ph2]
    current.photos = [ph3, ph4]
    #expect(current.changedPhotos(input) == [ph1, ph2])

    input.photos = [ph1, ph2, ph3]
    current.photos = [ph3, ph4]
    #expect(current.changedPhotos(input) == [ph1, ph2])

    input.photos = [ph1Modified, ph3]
    current.photos = [ph1, ph3, ph2, ph4]
    #expect(current.changedPhotos(input).map { $0.name }.sorted() == ["photo1"])

    input.photos = [ph1Modified, ph3, ph2, ph4]
    current.photos = [ph1, ph3]
    #expect(
      current.changedPhotos(input).map { $0.name }.sorted()
        == ["photo1", "photo2", "photo4"])
  }

  @Test func changedAlbumsDetectedViaSetDifference() {
    var input = Album(name: "root", path: "", parents: [])
    var current = Album(name: "root", path: "", parents: [])

    let child1 = Album(name: "child1", path: "", parents: [])
    let child2 = Album(name: "child2", path: "", parents: [])
    let child3 = Album(name: "child3", path: "", parents: [])
    var child1Variant = Album(name: "child1", path: "", parents: [])
    child1Variant.photos = [Photo(name: "photo4")]
    var child1Deep = Album(name: "child1", path: "", parents: [])
    child1Deep.photos = [Photo(name: "photo2")]

    input.albums = [child1, child2]
    current.albums = [child3]
    #expect(current.changedAlbums(input) == [child1, child2])

    input.albums = [child1, child2]
    current.albums = [child2, child3]
    #expect(current.changedAlbums(input) == [child1])

    input.albums = [child1Variant, child3]
    current.albums = [child1, child2]
    #expect(
      current.changedAlbums(input).map { $0.name }.sorted() == ["child1", "child3"])

    var parentOfChild1 = Album(name: "parentOfChild1", path: "", parents: [])
    var parentOfChild1Deep = Album(name: "parentOfChild1", path: "", parents: [])

    parentOfChild1.albums = [child1]
    parentOfChild1Deep.albums = [child1Deep]

    var parentOfParentOfChild1 = Album(name: "parentOfParentOfChild1", path: "", parents: [])
    var parentOfParentOfChild1Deep = Album(
      name: "parentOfParentOfChild1", path: "", parents: [])

    parentOfParentOfChild1.albums = [parentOfChild1]
    parentOfParentOfChild1Deep.albums = [parentOfChild1Deep]

    input.albums = [parentOfParentOfChild1Deep]
    current.albums = [parentOfParentOfChild1]
    #expect(
      current.changedAlbums(input).map { $0.name }.sorted() == ["parentOfParentOfChild1"])
  }

  @Test func changedAlbumsDetectsInputHasExtraChild() {
    var input = Album(name: "root", path: "", parents: [])
    let current = Album(name: "root", path: "", parents: [])

    let child = Album(name: "child1", path: "", parents: [])
    input.albums = [child]
    let changed = current.changedAlbums(input)
    #expect(changed.count == 1)
    #expect(Array(changed)[0] == child)
  }
}
