import Config
import XCTest

@testable import MuninKit

final class KeywordTests: XCTestCase {
  let albumPath = "example/album/"
  let outPath = "example/content/"
  let configPath = "example/munin.json"
  let peoplePath = "example/people.json"
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
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.
    XCTAssertEqual("test", "test")
  }

  func testBuildKeywordsFromAlbum() {
    let album = readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath, outPath: outPath, name: "test", parents: [])

    let keywords = buildKeywordsFromAlbum(album: album)

    XCTAssertEqual(keywords.count, 77)

    let strings = keywords.map { $0.name }

    XCTAssertTrue(strings.contains("Midtøsten"))
    XCTAssertTrue(strings.contains("Århus"))
    XCTAssertTrue(strings.contains("Tel Aviv District"))
    XCTAssertTrue(strings.contains("Aishling Cooke"))
  }

  func testPeopleFiles() {
    config = GalleryConfiguration(
      name: "peopleFilesTest",
      people: ["Man Person", "BoJo Trump", "Ola Nordmann"],
      peopleFiles: [peoplePath],
      resolutions: [100, 200, 300],
      jpegCompression: 0.1,
      inputPath: albumPath,
      outputPath: outPath,
      fileExtensions: ["jpg", "jpeg", "JPG", "JPEG"],
      concurrency: -1,
      logLevel: 1,
      diff: false,
      progress: false
    )
    XCTAssertEqual(config.allPeople().count, 0)
    config.combinePeople()
    XCTAssertEqual(config.allPeople().count, 4)
  }

  func testPeopleFilesAuto() {
    XCTAssertEqual(config.allPeople().count, 16)
  }
}
