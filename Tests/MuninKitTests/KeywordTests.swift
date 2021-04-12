import Configuration
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
    let manager = ConfigurationManager()
    manager
      .load(file: configPath, relativeFrom: .customPath("")).load(["progress": false])
    config = GalleryConfiguration(manager)
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

    XCTAssertEqual(keywords.count, 79)

    let strings = keywords.map { $0.name }

    XCTAssertTrue(strings.contains("Midtøsten"))
    XCTAssertTrue(strings.contains("Århus"))
    XCTAssertTrue(strings.contains("Tel Aviv District"))
    XCTAssertTrue(strings.contains("Aishling Cooke"))
  }

  func testPeopleFiles() {
    let manager = ConfigurationManager()
    manager
      .load([
        "people": ["Man Person", "BoJo Trump", "Ola Nordmann"],
        "peopleFiles": [peoplePath],
      ])
    config = GalleryConfiguration(manager)

    XCTAssertEqual(config.allPeople().count, 4)
  }

  func testPeopleFilesAuto() {
    XCTAssertEqual(config.allPeople().count, 16)
  }
}
