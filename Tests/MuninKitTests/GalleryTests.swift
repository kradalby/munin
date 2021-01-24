import Config
import Foundation
import XCTest

@testable import MuninKit

final class GalleryTests: XCTestCase {
  let albumPath = "example/album/"
  var config: GalleryConfiguration!
  var ctx: Context!
  var testName: String!
  var testDirectoryPath: String!

  override func setUp() {
    super.setUp()
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

    config = GalleryConfiguration(
      name: testName,
      people: [],
      resolutions: [100, 200, 300],
      jpegCompression: 0.1,
      inputPath: albumPath,
      outputPath: testDirectoryPath,
      fileExtentions: ["jpg", "jpeg", "JPG", "JPEG"],
      logLevel: 1,
      diff: false,
      concurrency: -1,
      progress: false
    )

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

  func testReadInputGallery() {
    let gallery = Gallery(ctx: ctx)
    XCTAssertEqual(gallery.input.numberOfPhotos(travers: true), 102)
    XCTAssertEqual(gallery.input.numberOfAlbums(travers: true), 10)
    XCTAssertEqual(gallery.output, nil)
  }

  func testReadInputOutputGallery() {
    let gallery = Gallery(ctx: ctx)
    XCTAssertEqual(gallery.input.numberOfPhotos(travers: true), 102)
    XCTAssertEqual(gallery.input.numberOfAlbums(travers: true), 10)
    XCTAssertNil(gallery.output)

    gallery.build(ctx: ctx, jsonOnly: false)

    let gallery2 = Gallery(ctx: ctx)
    XCTAssertNotNil(gallery2.output)
    XCTAssertEqual(gallery2.output!.numberOfPhotos(travers: true), 102)
    XCTAssertEqual(gallery2.output!.numberOfAlbums(travers: true), 10)
  }

  func testDiffGalleryNoDiff() {
    let gallery = Gallery(ctx: ctx)
    XCTAssertEqual(gallery.input.numberOfPhotos(travers: true), 102)
    XCTAssertEqual(gallery.input.numberOfAlbums(travers: true), 10)
    XCTAssertNil(gallery.output)

    gallery.build(ctx: ctx, jsonOnly: false)

    let gallery2 = Gallery(ctx: ctx)

    XCTAssertNil(gallery2.addedContent)
  }

  func testDiffGalleryAddedAlbum() {
    let gallery = Gallery(ctx: ctx)
    XCTAssertEqual(gallery.input.numberOfPhotos(travers: true), 102)
    XCTAssertEqual(gallery.input.numberOfAlbums(travers: true), 10)
    XCTAssertNil(gallery.output)

    gallery.build(ctx: ctx, jsonOnly: false)

    //
    let fm = FileManager()
    let deletePath = joinPath(testDirectoryPath, testName, "2018", "2018-03-10_Alkmaar")
    do {
      try fm.removeItem(atPath: deletePath)
    } catch {
      print("Failed to delete directory in test output during test: " + deletePath)
      XCTFail()
    }

    let gallery2 = Gallery(ctx: ctx)
    XCTAssertEqual(gallery2.input.numberOfPhotos(travers: true), 102)
    XCTAssertEqual(gallery2.input.numberOfAlbums(travers: true), 10)
    XCTAssertNotNil(gallery2.output)
    XCTAssertEqual(gallery2.output!.numberOfPhotos(travers: true), 56)
    XCTAssertEqual(gallery2.output!.numberOfAlbums(travers: true), 9)

    prettyPrintAdded(gallery2.addedContent!)

    XCTAssertNotNil(gallery2.addedContent)
    XCTAssertEqual(gallery2.addedContent!.numberOfPhotos(travers: true), 46)
    XCTAssertEqual(gallery2.addedContent!.numberOfAlbums(travers: true), 2)
  }

  func testDiffGalleryAddedPhotos() {
    let gallery = Gallery(ctx: ctx)
    XCTAssertEqual(gallery.input.numberOfPhotos(travers: true), 102)
    XCTAssertEqual(gallery.input.numberOfAlbums(travers: true), 10)
    XCTAssertNil(gallery.output)

    gallery.build(ctx: ctx, jsonOnly: false)

    //
    let fm = FileManager()
    for photo in [
      "20180310-143405-IMG_6010.json",
      "20180310-143656-IMG_6012.json",
      "20180310-144346-IMG_6013.json",
      "20180310-144514-IMG_6014.json",
      "20180310-144523-IMG_6015.json",
      "20180310-144631-IMG_6016.json",
      "20180310-150725-IMG_6017.json",
      "20180310-151102-IMG_6018.json",
      "20180310-151205-IMG_6019.json",
    ] {
      let deletePath = joinPath(testDirectoryPath, testName, "2018", "2018-03-10_Alkmaar", photo)
      do {
        try fm.removeItem(atPath: deletePath)
      } catch {
        print("Failed to delete directory in test output during test: " + deletePath)
        XCTFail()
      }

    }

    let gallery2 = Gallery(ctx: ctx)
    XCTAssertEqual(gallery2.input.numberOfPhotos(travers: true), 102)
    XCTAssertEqual(gallery2.input.numberOfAlbums(travers: true), 10)
    XCTAssertNotNil(gallery2.output)
    XCTAssertEqual(gallery2.output!.numberOfPhotos(travers: true), 93)
    XCTAssertEqual(gallery2.output!.numberOfAlbums(travers: true), 10)

    prettyPrintAdded(gallery2.addedContent!)

    XCTAssertNotNil(gallery2.addedContent)
    XCTAssertEqual(gallery2.addedContent!.numberOfPhotos(travers: true), 9)
    XCTAssertEqual(gallery2.addedContent!.numberOfAlbums(travers: true), 2)
  }

  func testClean() {
    let gallery = Gallery(ctx: ctx)
    XCTAssertEqual(gallery.input.numberOfPhotos(travers: true), 102)
    XCTAssertEqual(gallery.input.numberOfAlbums(travers: true), 10)
    XCTAssertNil(gallery.output)

    gallery.build(ctx: ctx, jsonOnly: false)

    // Output, empty, does nothing
    gallery.clean(ctx: ctx)

    var gallery2 = Gallery(ctx: ctx)
    XCTAssertEqual(gallery2.input.numberOfPhotos(travers: true), 102)
    XCTAssertEqual(gallery2.input.numberOfAlbums(travers: true), 10)
    XCTAssertNotNil(gallery2.output)
    XCTAssertEqual(gallery2.output!.numberOfPhotos(travers: true), 102)
    XCTAssertEqual(gallery2.output!.numberOfAlbums(travers: true), 10)

    var albums = Array(gallery2.input.albums)
    albums.removeAll(where: { $0.name == "2018" })
    var input = gallery2.input
    input.albums = Set(albums)
    gallery2.setInput(input)
    XCTAssertEqual(gallery2.input.numberOfPhotos(travers: true), 22)
    XCTAssertEqual(gallery2.input.numberOfAlbums(travers: true), 5)
    XCTAssertEqual(gallery2.output!.numberOfPhotos(travers: true), 102)
    XCTAssertEqual(gallery2.output!.numberOfAlbums(travers: true), 10)

    gallery2.clean(ctx: ctx)

    let gallery3 = Gallery(ctx: ctx)
    XCTAssertEqual(gallery3.input.numberOfPhotos(travers: true), 102)
    XCTAssertEqual(gallery3.input.numberOfAlbums(travers: true), 10)
    XCTAssertNotNil(gallery3.output)
    XCTAssertEqual(gallery3.output!.numberOfPhotos(travers: true), 22)
    XCTAssertEqual(gallery3.output!.numberOfAlbums(travers: true), 5)
  }
}
