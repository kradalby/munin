import Config
import XCTest

@testable import MuninKit

final class KeywordTests: XCTestCase {
  func test() {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.
    XCTAssertEqual("test", "test")
  }

  func testBuildKeywordsFromAlbum() {
    let config = Config.readConfig(configFormat: GalleryConfiguration.self, atPath: configPath)
    let ctx = Context(config: config)

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
}
