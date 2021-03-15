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
    XCTAssertEqual(photoCount, 103)
    let albumCount = album.numberOfAlbums(travers: true)
    XCTAssertEqual(albumCount, 10)
  }

  func testExpectedFiles() {
    let album = readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath + "/Misc", outPath: outPath, name: "test",
      parents: [Parent(name: "", url: "")])

    let photoCount = album.numberOfPhotos(travers: true)
    XCTAssertEqual(photoCount, 3)
    let albumCount = album.numberOfAlbums(travers: true)
    XCTAssertEqual(albumCount, 0)

    let contentDir = URL(fileURLWithPath: "example/content", isDirectory: true)

    let expectedFiles = [
      "\(contentDir.path)/test/20180510-171752-IMG_7165.json",
      "\(contentDir.path)/test/20180510-171752-IMG_7165_180.jpg",
      "\(contentDir.path)/test/20180510-171752-IMG_7165_220.jpg",
      "\(contentDir.path)/test/20180510-171752-IMG_7165_340.jpg",
      "\(contentDir.path)/test/20180510-171752-IMG_7165_576.jpg",
      "\(contentDir.path)/test/20180510-171752-IMG_7165_original.jpg",
      "\(contentDir.path)/test/index.json",
      "\(contentDir.path)/test/test_special_chars.json",
      "\(contentDir.path)/test/test_special_chars_180.jpg",
      "\(contentDir.path)/test/test_special_chars_220.jpg",
      "\(contentDir.path)/test/test_special_chars_original.jpg",
      "\(contentDir.path)/test/portrait_mm.json",
      "\(contentDir.path)/test/portrait_mm_180.jpeg",
      "\(contentDir.path)/test/portrait_mm_220.jpeg",
      "\(contentDir.path)/test/portrait_mm_340.jpeg",
      "\(contentDir.path)/test/portrait_mm_576.jpeg",
      "\(contentDir.path)/test/portrait_mm_768.jpeg",
      "\(contentDir.path)/test/portrait_mm_992.jpeg",
      "\(contentDir.path)/test/portrait_mm_1200.jpeg",
      "\(contentDir.path)/test/portrait_mm_1600.jpeg",
      "\(contentDir.path)/test/portrait_mm_original.jpeg",
    ].sorted()
    let actualFiles = album.expectedFiles().map { $0.path }.sorted()
    XCTAssertEqual(actualFiles, expectedFiles)
  }

  func testUnreferencedFilesNoOutputDirectory() {
    let album = readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath + "/Misc", outPath: outPath, name: "test",
      parents: [Parent(name: "", url: "")])

    let photoCount = album.numberOfPhotos(travers: true)
    XCTAssertEqual(photoCount, 3)
    let albumCount = album.numberOfAlbums(travers: true)
    XCTAssertEqual(albumCount, 0)

    let unreferenced = album.unreferencedFiles()

    XCTAssertEqual(unreferenced, [])
  }

  func testUnreferencedFilesWithOutputDirectory() {
    let album = readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath, outPath: outPath, name: "root", parents: [])

    let photoCount = album.numberOfPhotos(travers: true)
    XCTAssertEqual(photoCount, 103)
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
    XCTAssertEqual(photoCount, 3)
    let albumCount = album.numberOfAlbums(travers: true)
    XCTAssertEqual(albumCount, 0)

    let contentDir = URL(fileURLWithPath: "example/content", isDirectory: true)

    let expectedFiles = [
      "\(contentDir.path)/test/20180510-171752-IMG_7165.json",
      "\(contentDir.path)/test/20180510-171752-IMG_7165_180.jpg",
      "\(contentDir.path)/test/20180510-171752-IMG_7165_220.jpg",
      "\(contentDir.path)/test/20180510-171752-IMG_7165_340.jpg",
      "\(contentDir.path)/test/20180510-171752-IMG_7165_576.jpg",
      "\(contentDir.path)/test/20180510-171752-IMG_7165_original.jpg",
      "\(contentDir.path)/test/index.json",
      "\(contentDir.path)/test/test_special_chars.json",
      "\(contentDir.path)/test/test_special_chars_180.jpg",
      "\(contentDir.path)/test/test_special_chars_220.jpg",
      "\(contentDir.path)/test/test_special_chars_original.jpg",
      "\(contentDir.path)/test/portrait_mm.json",
      "\(contentDir.path)/test/portrait_mm_180.jpeg",
      "\(contentDir.path)/test/portrait_mm_220.jpeg",
      "\(contentDir.path)/test/portrait_mm_340.jpeg",
      "\(contentDir.path)/test/portrait_mm_576.jpeg",
      "\(contentDir.path)/test/portrait_mm_768.jpeg",
      "\(contentDir.path)/test/portrait_mm_992.jpeg",
      "\(contentDir.path)/test/portrait_mm_1200.jpeg",
      "\(contentDir.path)/test/portrait_mm_1600.jpeg",
      "\(contentDir.path)/test/portrait_mm_original.jpeg",
    ].sorted()
    let missing = album.missingFiles().map { $0.path }.sorted()

    XCTAssertEqual(missing, expectedFiles)
  }

  func testMissingFilesWithOutputDirectory() {
    let album = readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath, outPath: outPath, name: "root", parents: [])

    let photoCount = album.numberOfPhotos(travers: true)
    XCTAssertEqual(photoCount, 103)
    let albumCount = album.numberOfAlbums(travers: true)
    XCTAssertEqual(albumCount, 10)

    let expectedFiles: [String] = []
    let missing = album.missingFiles().map { $0.path }.sorted()

    XCTAssertEqual(missing, expectedFiles)
  }

  func testChangedPhotos() {
    var input = Album(name: "root", path: "", parents: [])
    var current = Album(name: "root", path: "", parents: [])
    let ph1 = Photo(
      name: "photo1", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [],
      modifiedDate: Date(timeIntervalSince1970: 1_610_472_000), parents: [])
    let ph2 = Photo(name: "photo2")
    let ph3 = Photo(name: "photo3")
    let ph4 = Photo(name: "photo4")
    let ph1_2 = Photo(
      name: "photo1", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [],
      modifiedDate: Date(timeIntervalSince1970: 1_610_471_000), parents: [])

    input.photos = [ph1, ph2]
    current.photos = [ph3, ph4]
    XCTAssertEqual(current.changedPhotos(input), [ph1, ph2])

    input.photos = [ph1, ph2, ph3]
    current.photos = [ph3, ph4]
    XCTAssertEqual(current.changedPhotos(input), [ph1, ph2])

    input.photos = [ph1_2, ph3]
    current.photos = [ph1, ph3, ph2, ph4]
    XCTAssertEqual(
      current.changedPhotos(input).map { $0.name }.sorted(), ["photo1"])

    input.photos = [ph1_2, ph3, ph2, ph4]
    current.photos = [ph1, ph3]
    XCTAssertEqual(
      current.changedPhotos(input).map { $0.name }.sorted(), ["photo1", "photo2", "photo4"])
  }

  func testChangedAlbums() {
    var input = Album(name: "root", path: "", parents: [])
    var current = Album(name: "root", path: "", parents: [])

    let child1 = Album(name: "child1", path: "", parents: [])
    let child2 = Album(name: "child2", path: "", parents: [])
    let child3 = Album(name: "child3", path: "", parents: [])
    var child1_2 = Album(name: "child1", path: "", parents: [])
    child1_2.photos = [Photo(name: "photo4")]
    var child1_3 = Album(name: "child1", path: "", parents: [])
    child1_3.photos = [Photo(name: "photo2")]

    input.albums = [child1, child2]
    current.albums = [child3]
    XCTAssertEqual(current.changedAlbums(input), [child1, child2])

    input.albums = [child1, child2]
    current.albums = [child2, child3]
    XCTAssertEqual(current.changedAlbums(input), [child1])

    input.albums = [child1_2, child3]
    current.albums = [child1, child2]
    XCTAssertEqual(
      current.changedAlbums(input).map { $0.name }.sorted(), ["child1", "child3"])

    var parentOfChild1 = Album(name: "parentOfChild1", path: "", parents: [])
    var parentOfChild1_3 = Album(name: "parentOfChild1", path: "", parents: [])

    parentOfChild1.albums = [child1]
    parentOfChild1_3.albums = [child1_3]

    var parentOfParentOfChild1 = Album(name: "parentOfParentOfChild1", path: "", parents: [])
    var parentOfParentOfChild1_3 = Album(name: "parentOfParentOfChild1", path: "", parents: [])

    parentOfParentOfChild1.albums = [parentOfChild1]
    parentOfParentOfChild1_3.albums = [parentOfChild1_3]

    input.albums = [parentOfParentOfChild1_3]
    current.albums = [parentOfParentOfChild1]
    XCTAssertEqual(
      current.changedAlbums(input).map { $0.name }.sorted(), ["parentOfParentOfChild1"])

  }

  func testChangedAlbumsInputHasChildAlbum() {
    // input has a new child
    var input2 = Album(name: "root", path: "", parents: [])
    let current2 = Album(name: "root", path: "", parents: [])

    let child_2 = Album(name: "child1", path: "", parents: [])
    input2.albums = [child_2]
    let changed2 = current2.changedAlbums(input2)
    XCTAssertNotNil(changed2)
    XCTAssertEqual(changed2.count, 1)
    XCTAssertEqual(Array(changed2)[0], child_2)
  }

  func testClean() {}

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
