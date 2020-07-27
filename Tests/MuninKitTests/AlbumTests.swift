import Config
import XCTest

@testable import MuninKit

let albumPath = "example/album/"
let outPath = "example/content/"
let configPath = "example/munin.json"

final class AlbumTests: XCTestCase {
  func test() {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.
    XCTAssertEqual("test", "test")
  }

  func testReadStateFromInputDirectory() {
    let config = Config.readConfig(configFormat: GalleryConfiguration.self, atPath: configPath)
    let ctx = Context(config: config)

    let album = readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath, outPath: outPath, name: "test", parents: [])

    let photoCount = album.numberOfPhotos(travers: true)
    XCTAssertEqual(photoCount, 100)
    let albumCount = album.numberOfAlbums(travers: true)
    XCTAssertEqual(albumCount, 9)
  }

  // This is a silly test to ensure that concurrency does not
  // cause inconsistent reads of the albums
  func testReadStateFromInputDirectoryMultipleTime() {
    let config = Config.readConfig(configFormat: GalleryConfiguration.self, atPath: configPath)

    for _ in 1...100 {
      let ctx = Context(config: config)
      let album = readStateFromInputDirectory(
        ctx: ctx, atPath: albumPath, outPath: outPath, name: "test", parents: [])

      let photoCount = album.numberOfPhotos(travers: true)
      XCTAssertEqual(photoCount, 102)
      let albumCount = album.numberOfAlbums(travers: true)
      XCTAssertEqual(albumCount, 10)
    }
  }

  static var __allTests = [
    ("test", test),
    ("testReadStateFromInputDirectory", testReadStateFromInputDirectory),
    ("testReadStateFromInputDirectoryMultipleTime", testReadStateFromInputDirectoryMultipleTime),
  ]
}
