import Config
import XCTest

@testable import MuninKit

final class PhotoTests: XCTestCase {
  let photoPath = "example/album/2017/2017-12-22 Juleferie/20171222-132846-20171222-IMG_5259.jpg"
  let photo2Path = "example/album/2017/2017-12-22 Juleferie/20171224-165120-20171224-IMG_5284.jpg"
  let photo3Path = "example/album/2017/2017-12-19 Aarhus/20171219-143810-20171219-IMG_5246-2.jpg"
  let outPath = "example/content/"
  let configPath = "example/munin.json"

  func test() {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.
    XCTAssertEqual("test", "test")
  }

  func testExpectedValuesRead() {
    let config = Config.readConfig(
      configFormat: GalleryConfiguration.self, atPath: configPath)

    let ctx = Context(config: config)

    let photo = readPhotoFromPath(
      atPath: photoPath, outPath: outPath, name: "test", fileExtension: "jpg", parents: [],
      ctx: ctx
    )

    let photo2 = readPhotoFromPath(
      atPath: photo2Path, outPath: outPath, name: "test2", fileExtension: "jpg", parents: [],
      ctx: ctx
    )

    let photo3 = readPhotoFromPath(
      atPath: photo3Path, outPath: outPath, name: "test3", fileExtension: "jpg", parents: [],
      ctx: ctx
    )

    XCTAssertEqual(photo?.name, "test")
    XCTAssertEqual(photo?.url, "example/content//test.json")
    XCTAssertEqual(photo?.scaledPhotos.count, 7)
    XCTAssertEqual(photo?.aperture, 2.64386)
    XCTAssertEqual(photo?.orientation, Orientation.landscape)
    XCTAssertEqual(photo?.people.map { $0.name }, ["Angel Dalby"])
    XCTAssertEqual(
      photo?.keywords.map { $0.name }.sorted(),
      ["Jul", "Aspargesgården", "Christmas", "Tjodalyng", "2017", "Norway", "Vestfold"].sorted())

    XCTAssertEqual(photo2?.name, "test2")
    XCTAssertEqual(photo2?.url, "example/content//test2.json")
    XCTAssertEqual(photo2?.scaledPhotos.count, 7)
    XCTAssertEqual(photo2?.aperture, 2.97085)
    XCTAssertEqual(photo2?.orientation, Orientation.landscape)
    XCTAssertEqual(photo2?.people.map { $0.name }, ["Angel Dalby"])
    XCTAssertEqual(
      photo2?.keywords.map { $0.name }.sorted(),
      ["Aspargesgården", "Tjodalyng", "Norway", "Jul", "2017", "Vestfold", "Christmas"].sorted())

    XCTAssertEqual(photo3?.name, "test3")
    XCTAssertEqual(photo3?.url, "example/content//test3.json")
    XCTAssertEqual(photo3?.scaledPhotos.count, 7)
    XCTAssertEqual(photo3?.aperture, 4.64386)
    XCTAssertEqual(photo3?.orientation, Orientation.portrait)
    XCTAssertEqual(photo3?.people.map { $0.name }, [])
    XCTAssertEqual(
      photo3?.keywords.map { $0.name }.sorted(),
      ["Denmark", "2017", "Århus", "Central Denmark Region", "DK", "Street art"].sorted())
  }

  func testExpectedFiles() {
    let config = Config.readConfig(
      configFormat: GalleryConfiguration.self, atPath: configPath)

    let ctx = Context(config: config)

    let photo = readPhotoFromPath(
      atPath: photoPath, outPath: outPath, name: "test", fileExtension: "jpg", parents: [],
      ctx: ctx
    )

    let expectedFiles = [
      "test.json", "test_180.jpg", "test_220.jpg",
      "test_340.jpg", "test_576.jpg", "test_768.jpg",
      "test_992.jpg", "test_1200.jpg", "test_original.jpg",
    ].map { URL(fileURLWithPath: "example/content/" + $0).path }.sorted()
    let actualFiles = photo!.expectedFiles().map { $0.path }.sorted()

    XCTAssertEqual(actualFiles, expectedFiles)
  }

  func testSortWithDateTimes() {
    let unsorted = [
      Photo(
        name: "atest3", dateTime: Date(timeIntervalSince1970: 1_610_473_000)),
      Photo(
        name: "xtest1", dateTime: Date(timeIntervalSince1970: 1_610_470_000)),
      Photo(
        name: "btest2", dateTime: Date(timeIntervalSince1970: 1_610_472_000)),
    ]

    let unsortedNames = unsorted.map { $0.name }
    XCTAssertEqual(unsortedNames, ["atest3", "xtest1", "btest2"])

    let sorted = unsorted.sorted().map { $0.name }
    XCTAssertEqual(sorted, ["xtest1", "btest2", "atest3"])
  }

  func testSortWithNoDateTimes() {
    let unsorted = [
      Photo(
        name: "btest3"),
      Photo(
        name: "ctest1"),
      Photo(
        name: "atest2"),
    ]

    let unsortedNames = unsorted.map { $0.name }
    XCTAssertEqual(unsortedNames, ["btest3", "ctest1", "atest2"])

    let sorted = unsorted.sorted().map { $0.name }
    XCTAssertEqual(sorted, ["atest2", "btest3", "ctest1"])
  }

  func testSortWithMixDateTimesAndName() {
    let unsorted = [
      Photo(
        name: "test5"),
      Photo(
        name: "test6"),
      Photo(
        name: "test7", dateTime: Date(timeIntervalSince1970: 1_610_472_000)),
    ]

    let unsortedNames = unsorted.map { $0.name }
    XCTAssertEqual(unsortedNames, ["test5", "test6", "test7"])

    let sorted = unsorted.sorted().map { $0.name }
    XCTAssertEqual(sorted, ["test7", "test5", "test6"])
  }
}
