import Config
import XCTest

@testable import MuninKit

final class KeywordTests: XCTestCase {
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
}
