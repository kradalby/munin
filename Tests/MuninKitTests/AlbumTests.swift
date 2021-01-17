import Config
import XCTest

@testable import MuninKit

final class AlbumTests: XCTestCase {
  let albumPath = "example/album/"
  let outPath = "example/content/"
  let configPath = "example/munin.json"
  var config: GalleryConfiguration!
  var ctx: Context!

  override func setUp() {
    super.setUp()
    config = Config.readConfig(configFormat: GalleryConfiguration.self, atPath: configPath)
    config.progress = false
    ctx = Context(config: config)
  }

  override func tearDown() {
    config = nil
    ctx = nil
    super.tearDown()
  }

  func test() {
    XCTAssertEqual("test", "test")
  }

  func testReadStateFromInputDirectory() {

    let album = readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath, outPath: outPath, name: "test", parents: [])

    let photoCount = album.numberOfPhotos(travers: true)
    XCTAssertEqual(photoCount, 102)
    let albumCount = album.numberOfAlbums(travers: true)
    XCTAssertEqual(albumCount, 10)
  }

  func testExpectedFiles() {
    let album = readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath + "/Misc", outPath: outPath, name: "test",
      parents: [Parent(name: "", url: "")])

    let photoCount = album.numberOfPhotos(travers: true)
    XCTAssertEqual(photoCount, 2)
    let albumCount = album.numberOfAlbums(travers: true)
    XCTAssertEqual(albumCount, 0)

    let expectedFiles = [
      "/Users/kradalby/git/munin/example/content/test/20180510-171752-IMG_7165.json",
      "/Users/kradalby/git/munin/example/content/test/20180510-171752-IMG_7165_180.jpg",
      "/Users/kradalby/git/munin/example/content/test/20180510-171752-IMG_7165_220.jpg",
      "/Users/kradalby/git/munin/example/content/test/20180510-171752-IMG_7165_340.jpg",
      "/Users/kradalby/git/munin/example/content/test/20180510-171752-IMG_7165_576.jpg",
      "/Users/kradalby/git/munin/example/content/test/20180510-171752-IMG_7165_original.jpg",
      "/Users/kradalby/git/munin/example/content/test/index.json",
      "/Users/kradalby/git/munin/example/content/test/test_special_chars.json",
      "/Users/kradalby/git/munin/example/content/test/test_special_chars_180.jpg",
      "/Users/kradalby/git/munin/example/content/test/test_special_chars_220.jpg",
      "/Users/kradalby/git/munin/example/content/test/test_special_chars_original.jpg",
    ].sorted()
    let actualFiles = album.expectedFiles().map { $0.path }.sorted()

    XCTAssertEqual(actualFiles, expectedFiles)
  }

  func testUnreferencedFilesNoOutputDirectory() {
    let album = readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath + "/Misc", outPath: outPath, name: "test",
      parents: [Parent(name: "", url: "")])

    let photoCount = album.numberOfPhotos(travers: true)
    XCTAssertEqual(photoCount, 2)
    let albumCount = album.numberOfAlbums(travers: true)
    XCTAssertEqual(albumCount, 0)

    let unreferenced = album.unreferencedFiles()

    XCTAssertEqual(unreferenced, [])
  }

  func testUnreferencedFilesWithOutputDirectory() {
    let album = readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath, outPath: outPath, name: "root", parents: [])

    let photoCount = album.numberOfPhotos(travers: true)
    XCTAssertEqual(photoCount, 102)
    let albumCount = album.numberOfAlbums(travers: true)
    XCTAssertEqual(albumCount, 10)
    let unreferenced = album.unreferencedFiles()

    XCTAssertEqual(unreferenced, [])
  }

  func testMissingFilesNoOutputDirectory() {
    let album = readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath + "/Misc", outPath: outPath, name: "test",
      parents: [Parent(name: "", url: "")])

    let photoCount = album.numberOfPhotos(travers: true)
    XCTAssertEqual(photoCount, 2)
    let albumCount = album.numberOfAlbums(travers: true)
    XCTAssertEqual(albumCount, 0)

    let expectedFiles = [
      "/Users/kradalby/git/munin/example/content/test/20180510-171752-IMG_7165.json",
      "/Users/kradalby/git/munin/example/content/test/20180510-171752-IMG_7165_180.jpg",
      "/Users/kradalby/git/munin/example/content/test/20180510-171752-IMG_7165_220.jpg",
      "/Users/kradalby/git/munin/example/content/test/20180510-171752-IMG_7165_340.jpg",
      "/Users/kradalby/git/munin/example/content/test/20180510-171752-IMG_7165_576.jpg",
      "/Users/kradalby/git/munin/example/content/test/20180510-171752-IMG_7165_original.jpg",
      "/Users/kradalby/git/munin/example/content/test/index.json",
      "/Users/kradalby/git/munin/example/content/test/test_special_chars.json",
      "/Users/kradalby/git/munin/example/content/test/test_special_chars_180.jpg",
      "/Users/kradalby/git/munin/example/content/test/test_special_chars_220.jpg",
      "/Users/kradalby/git/munin/example/content/test/test_special_chars_original.jpg",
    ].sorted()
    let missing = album.missingFiles().map { $0.path }.sorted()

    XCTAssertEqual(missing, expectedFiles)
  }

  func testMissingFilesWithOutputDirectory() {
    let album = readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath, outPath: outPath, name: "root", parents: [])

    let photoCount = album.numberOfPhotos(travers: true)
    XCTAssertEqual(photoCount, 102)
    let albumCount = album.numberOfAlbums(travers: true)
    XCTAssertEqual(albumCount, 10)

    let expectedFiles: [String] = []
    let missing = album.missingFiles().map { $0.path }.sorted()

    XCTAssertEqual(missing, expectedFiles)
  }

  // This is a silly test to ensure that concurrency does not
  // cause inconsistent reads of the albums
  // func testReadStateFromInputDirectoryMultipleTime() {
  //   let config = Config.readConfig(configFormat: GalleryConfiguration.self, atPath: configPath)

  //   for _ in 1...100 {
  //     let ctx = Context(config: config)
  //     let album = readStateFromInputDirectory(
  //       ctx: ctx, atPath: albumPath, outPath: outPath, name: "test", parents: [])

  //     let photoCount = album.numberOfPhotos(travers: true)
  //     XCTAssertEqual(photoCount, 102)
  //     let albumCount = album.numberOfAlbums(travers: true)
  //     XCTAssertEqual(albumCount, 10)
  //   }
  // }
}
