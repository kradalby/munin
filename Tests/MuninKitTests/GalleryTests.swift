import Foundation
import XCTest

@testable import MuninKit

final class GalleryTests: XCTestCase {
  let albumPath = "example/album/"
  let peoplePath = "example/people.json"
  var config: GalleryConfiguration!
  var ctx: Context!
  var testName: String!
  var testDirectoryPath: String!

  override func setUp() {
    super.setUp()
    VIPSSetup.ensure()
    let fm = FileManager()
    testName = randomString(length: 10)
    testDirectoryPath = joinPath(fm.temporaryDirectory.path, testName)
    print("Setting up tests in: " + testDirectoryPath!)

    do {
      try fm.createDirectory(atPath: testDirectoryPath, withIntermediateDirectories: true)
    } catch {
      print("Failed to create directory: " + testDirectoryPath!)
      XCTFail()
    }

    let manager = ConfigurationManager()
    manager
      .load([
        "name": testName!,
        "people": [],
        "peopleFiles": [peoplePath],
        "resolutions": [100, 200, 300],
        "jpegCompression": 0.1,
        "sourceFolder": albumPath,
        "targetFolder": testDirectoryPath!,
        "fileExtensions": ["jpg", "jpeg", "JPG", "JPEG"],
        "diff": false,
        "progress": false,
      ])
    config = GalleryConfiguration(manager)

    ctx = Context(config: config)
  }

  override func tearDown() {
    let fm = FileManager()
    do {
      try fm.removeItem(atPath: testDirectoryPath)
    } catch {
      print("Failed to clean up directory: " + testDirectoryPath!)
      XCTFail()
    }

    super.tearDown()
  }

  func test() {
    XCTAssertEqual("test", "test")
  }

  func testReadInputGallery() async throws {
    let gallery = try await Gallery.load(ctx: ctx)
    XCTAssertEqual(gallery.input.numberOfPhotos(travers: true), 104)
    XCTAssertEqual(gallery.input.numberOfAlbums(travers: true), 12)
    XCTAssertEqual(gallery.output, nil)
  }

  func testReadInputOutputGallery() async throws {
    let gallery = try await Gallery.load(ctx: ctx)
    XCTAssertEqual(gallery.input.numberOfPhotos(travers: true), 104)
    XCTAssertEqual(gallery.input.numberOfAlbums(travers: true), 12)
    XCTAssertNil(gallery.output)

    try await gallery.build(ctx: ctx, jsonOnly: false)

    let gallery2 = try await Gallery.load(ctx: ctx)
    XCTAssertNotNil(gallery2.output)
    XCTAssertEqual(gallery2.output!.numberOfPhotos(travers: true), 104)
    XCTAssertEqual(gallery2.output!.numberOfAlbums(travers: true), 12)
  }

  func testDiffGalleryNoDiff() async throws {
    let gallery = try await Gallery.load(ctx: ctx)
    XCTAssertEqual(gallery.input.numberOfPhotos(travers: true), 104)
    XCTAssertEqual(gallery.input.numberOfAlbums(travers: true), 12)
    XCTAssertNil(gallery.output)

    try await gallery.build(ctx: ctx, jsonOnly: false)

    let gallery2 = try await Gallery.load(ctx: ctx)

    XCTAssertNil(gallery2.changedContent)
  }

  func testDiffGalleryAddedAlbum() async throws {
    let gallery = try await Gallery.load(ctx: ctx)
    XCTAssertEqual(gallery.input.numberOfPhotos(travers: true), 104)
    XCTAssertEqual(gallery.input.numberOfAlbums(travers: true), 12)
    XCTAssertNil(gallery.output)

    try await gallery.build(ctx: ctx, jsonOnly: false)

    let fm = FileManager()
    let deletePath = joinPath(
      testDirectoryPath, testName, "2018", "2018-03-10_AlkmaarÆØÅæøå")
    do {
      try fm.removeItem(atPath: deletePath)
    } catch {
      print("Failed to delete directory in test output during test: " + deletePath)
      XCTFail()
    }

    let gallery2 = try await Gallery.load(ctx: ctx)
    XCTAssertEqual(gallery2.input.numberOfPhotos(travers: true), 104)
    XCTAssertEqual(gallery2.input.numberOfAlbums(travers: true), 12)
    XCTAssertNotNil(gallery2.output)

    XCTAssertNotNil(gallery2.changedContent)
    // changedContent should contain the photos and album that disappeared
    // from the output directory — exactly the Alkmaar folder.
    XCTAssertGreaterThan(gallery2.changedContent!.numberOfPhotos(travers: true), 0)
    XCTAssertGreaterThan(gallery2.changedContent!.numberOfAlbums(travers: true), 0)
  }

  func testDiffGalleryAddedPhotos() async throws {
    let gallery = try await Gallery.load(ctx: ctx)
    XCTAssertEqual(gallery.input.numberOfPhotos(travers: true), 104)
    XCTAssertEqual(gallery.input.numberOfAlbums(travers: true), 12)
    XCTAssertNil(gallery.output)

    try await gallery.build(ctx: ctx, jsonOnly: false)

    let fm = FileManager()
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
      do {
        try fm.removeItem(atPath: deletePath)
      } catch {
        print("Failed to delete: " + deletePath + " (\(error))")
        XCTFail()
      }
    }

    let gallery2 = try await Gallery.load(ctx: ctx)
    XCTAssertEqual(gallery2.input.numberOfPhotos(travers: true), 104)
    XCTAssertEqual(gallery2.input.numberOfAlbums(travers: true), 12)
    XCTAssertNotNil(gallery2.output)

    XCTAssertNotNil(gallery2.changedContent)
    XCTAssertEqual(
      gallery2.changedContent!.numberOfPhotos(travers: true), photosToDelete.count)
  }

  func testClean() async throws {
    let gallery = try await Gallery.load(ctx: ctx)
    XCTAssertEqual(gallery.input.numberOfPhotos(travers: true), 104)
    XCTAssertEqual(gallery.input.numberOfAlbums(travers: true), 12)
    XCTAssertNil(gallery.output)

    try await gallery.build(ctx: ctx, jsonOnly: false)

    // Output, empty, does nothing
    gallery.clean(ctx: ctx)

    var gallery2 = try await Gallery.load(ctx: ctx)
    XCTAssertEqual(gallery2.input.numberOfPhotos(travers: true), 104)
    XCTAssertEqual(gallery2.input.numberOfAlbums(travers: true), 12)
    XCTAssertNotNil(gallery2.output)
    XCTAssertEqual(gallery2.output!.numberOfPhotos(travers: true), 104)
    XCTAssertEqual(gallery2.output!.numberOfAlbums(travers: true), 12)

    var albums = Array(gallery2.input.albums)
    albums.removeAll(where: { $0.name == "2018" })
    var input = gallery2.input
    input.albums = Set(albums)
    gallery2.setInput(input)
    XCTAssertEqual(gallery2.input.numberOfPhotos(travers: true), 24)
    XCTAssertEqual(gallery2.input.numberOfAlbums(travers: true), 7)
    XCTAssertEqual(gallery2.output!.numberOfPhotos(travers: true), 104)
    XCTAssertEqual(gallery2.output!.numberOfAlbums(travers: true), 12)

    gallery2.clean(ctx: ctx)

    let gallery3 = try await Gallery.load(ctx: ctx)
    XCTAssertEqual(gallery3.input.numberOfPhotos(travers: true), 104)
    XCTAssertEqual(gallery3.input.numberOfAlbums(travers: true), 12)
    XCTAssertNotNil(gallery3.output)
    XCTAssertEqual(gallery3.output!.numberOfPhotos(travers: true), 24)
    XCTAssertEqual(gallery3.output!.numberOfAlbums(travers: true), 7)
  }
}
