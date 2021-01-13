import Config
import XCTest

@testable import MuninKit

let photoPath = "example/album/2017/2017-12-22 Juleferie/20171222-132846-20171222-IMG_5259.jpg"
let photo2Path = "example/album/2017/2017-12-22 Juleferie/20171224-165120-20171224-IMG_5284.jpg"
let photo3Path = "example/album/2017/2017-12-19\ Aarhus/20171219-143810-20171219-IMG_5246-2.jpg"
let outPath = "example/content/"
let configPath = "example/munin.json"

final class PhotoTests: XCTestCase {
  var config: GalleryConfiguration
  var ctx: Context
  var photo: Photo
  var photo2: Photo

  override func setUp() {
    super.setUp()
    config = Config.readConfig(configFormat: GalleryConfiguration.self, atPath: configPath)
    ctx = Context(config: config)

    photo = readPhotoFromPath(
      ctx: ctx, atPath: photoPath, outPath: outPath, name: "test", parents: [], fileExtension: "jpg")
    photo2 = readPhotoFromPath(
      ctx: ctx, atPath: photo2Path, outPath: outPath, name: "test", parents: [], fileExtension: "jpg")
    photo3 = readPhotoFromPath(
      ctx: ctx, atPath: photo3Path, outPath: outPath, name: "test", parents: [], fileExtension: "jpg")
  }

  func test() {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.
    XCTAssertEqual("test", "test")
  }

  func testExpectedValuesRead() {
    XCTAssertEqual(photo.name, "test")
    XCTAssertEqual(photo.url, "test")
    XCTAssertEqual(photo.scaledPhotos.count, 0)
    XCTAssertEqual(photo.aperture, 0.0)
    XCTAssertEqual(photo.orientation, Orientation.landscape)
    XCTAssertEqual(photo.people, [])
    XCTAssertEqual(photo.keywords, [])

    XCTAssertEqual(photo2.name, "test")
    XCTAssertEqual(photo2.url, "test")
    XCTAssertEqual(photo2.scaledPhotos.count, 0)
    XCTAssertEqual(photo2.aperture, 0.0)
    XCTAssertEqual(photo2.orientation, Orientation.landscape)
    XCTAssertEqual(photo2.people, [])
    XCTAssertEqual(photo2.keywords, [])

    XCTAssertEqual(photo3.name, "test")
    XCTAssertEqual(photo3.url, "test")
    XCTAssertEqual(photo3.scaledPhotos.count, 0)
    XCTAssertEqual(photo3.aperture, 0.0)
    XCTAssertEqual(photo3.orientation, Orientation.portrait)
    XCTAssertEqual(photo3.people, [])
    XCTAssertEqual(photo3.keywords, [])
  }

  func testExpectedFiles() {
    let expectedFiles = ["test", "file2"].map {URL(fileURLWithPath: $0)}
    let actualFiles = photo.expectedFiles()

    XCTAssertEqual(actualFiles, expectedFiles)
  }

  func testSortWithDateTimes() {
    let unsorted = [
      Photo(name: "test3", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [], parents: []).modifiedDate = Date(timeIntervalSince1970: 1610473000),
      Photo(name: "test1", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [], parents: []).modifiedDate = Date(timeIntervalSince1970: 1610470000),
      Photo(name: "test2", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [], parents: []).modifiedDate = Date(timeIntervalSince1970: 1610472000),
    ]

    let unsortedNames = unsorted.map {$0.name}
    XCTAssertEqual(unsortedNames, ["test3", "test1", "test2"])

    let sorted = unsorted.sorted().map {$0.name}
    XCTAssertEqual(sorted, ["test1", "test2", "test3"])
  }

  func testSortWithNoDateTimes() {
    let unsorted = [
      Photo(name: "btest3", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [], parents: []),
      Photo(name: "ctest1", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [], parents: []),
      Photo(name: "atest2", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [], parents: []),
    ]

    let unsortedNames = unsorted.map {$0.name}
    XCTAssertEqual(unsortedNames, ["btest3", "ctest1", "atest2"])

    let sorted = unsorted.sorted().map {$0.name}
    XCTAssertEqual(sorted, ["atest2", "btest3", "ctest2"])
  }

  func testSortWithMixDateTimesAndName() {
    let unsorted = [
      Photo(name: "test5", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [], parents: []),
      Photo(name: "test6", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [], parents: []),
      Photo(name: "test7", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [], parents: []).modifiedDate = Date(timeIntervalSince1970: 1610472000),
    ]

    let unsortedNames = unsorted.map {$0.name}
    XCTAssertEqual(unsortedNames, ["test5", "test6", "test7"])

    let sorted = unsorted.sorted().map {$0.name}
    XCTAssertEqual(sorted, ["test7", "test5", "test6"])
  }
}
