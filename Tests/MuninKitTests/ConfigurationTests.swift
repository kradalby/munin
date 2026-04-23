import Foundation
import XCTest

@testable import MuninKit

final class ConfigurationTests: XCTestCase {

  func testDefaults() {
    let config = MuninConfiguration()
    XCTAssertEqual(config.name, "root")
    XCTAssertEqual(config.people, [])
    XCTAssertEqual(config.resolutions, MuninConfiguration.defaultResolutions)
    XCTAssertEqual(config.fileExtensions, MuninConfiguration.defaultFileExtensions)
    XCTAssertEqual(config.jpegCompression, 1.0)
    XCTAssertFalse(config.diff)
    XCTAssertTrue(config.progress)
  }

  func testCodableRoundTrip() throws {
    let original = MuninConfiguration(
      name: "gallery",
      people: ["Alice", "Bob"],
      resolutions: [100, 200, 300],
      sourceFolder: "/in",
      targetFolder: "/out"
    )
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(MuninConfiguration.self, from: encoded)
    XCTAssertEqual(decoded.name, original.name)
    XCTAssertEqual(decoded.people, original.people)
    XCTAssertEqual(decoded.resolutions, original.resolutions)
    XCTAssertEqual(decoded.sourceFolder, original.sourceFolder)
    XCTAssertEqual(decoded.targetFolder, original.targetFolder)
  }

  func testDecodeWithMissingKeysFillsDefaults() throws {
    let json = #"{"name":"custom","sourceFolder":"/src"}"#
    let decoded = try JSONDecoder().decode(MuninConfiguration.self, from: Data(json.utf8))
    XCTAssertEqual(decoded.name, "custom")
    XCTAssertEqual(decoded.sourceFolder, "/src")
    // Unspecified values should fall back to defaults:
    XCTAssertEqual(decoded.resolutions, MuninConfiguration.defaultResolutions)
    XCTAssertEqual(decoded.fileExtensions, MuninConfiguration.defaultFileExtensions)
    XCTAssertTrue(decoded.progress)
  }

  func testManagerDictionaryOverrides() {
    let manager = ConfigurationManager()
    manager.load([
      "name": "test-gallery",
      "people": ["Alice"],
      "resolutions": [100, 200],
      "progress": false,
    ])
    XCTAssertEqual(manager["name"] as? String, "test-gallery")
    XCTAssertEqual(manager["people"] as? [String], ["Alice"])
    XCTAssertEqual(manager["resolutions"] as? [Int], [100, 200])
    XCTAssertEqual(manager["progress"] as? Bool, false)
  }

  func testManagerOverridesTakePrecedenceOverFile() throws {
    // Write a temp config file
    let tmp = URL(
      fileURLWithPath: NSTemporaryDirectory()
    ).appendingPathComponent("munin-config-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: tmp) }
    let fileJSON = #"{"name":"from-file","sourceFolder":"/file-src"}"#
    try Data(fileJSON.utf8).write(to: tmp)

    let manager = ConfigurationManager()
    manager.load(file: tmp.path, relativeFrom: .pwd)
    manager.load(["name": "from-override"])

    XCTAssertEqual(manager["name"] as? String, "from-override")  // dict wins
    XCTAssertEqual(manager["sourceFolder"] as? String, "/file-src")  // file value retained
  }

  func testManagerReturnsNilForUnknownKey() {
    let manager = ConfigurationManager()
    XCTAssertNil(manager["totally-unknown-key"])
  }
}
