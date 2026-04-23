import Foundation
import Testing

@testable import MuninKit

@Suite
struct ConfigurationTests {

  @Test func defaults() {
    let config = MuninConfiguration()
    #expect(config.name == "root")
    #expect(config.people == [])
    #expect(config.resolutions == MuninConfiguration.defaultResolutions)
    #expect(config.fileExtensions == MuninConfiguration.defaultFileExtensions)
    #expect(config.jpegCompression == 1.0)
    #expect(!config.diff)
    #expect(config.progress)
  }

  @Test func codableRoundTrip() throws {
    let original = MuninConfiguration(
      name: "gallery",
      people: ["Alice", "Bob"],
      resolutions: [100, 200, 300],
      sourceFolder: "/in",
      targetFolder: "/out"
    )
    let encoded = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(MuninConfiguration.self, from: encoded)
    #expect(decoded.name == original.name)
    #expect(decoded.people == original.people)
    #expect(decoded.resolutions == original.resolutions)
    #expect(decoded.sourceFolder == original.sourceFolder)
    #expect(decoded.targetFolder == original.targetFolder)
  }

  @Test func decodeWithMissingKeysFillsDefaults() throws {
    let json = #"{"name":"custom","sourceFolder":"/src"}"#
    let decoded = try JSONDecoder().decode(MuninConfiguration.self, from: Data(json.utf8))
    #expect(decoded.name == "custom")
    #expect(decoded.sourceFolder == "/src")
    // Unspecified values should fall back to defaults:
    #expect(decoded.resolutions == MuninConfiguration.defaultResolutions)
    #expect(decoded.fileExtensions == MuninConfiguration.defaultFileExtensions)
    #expect(decoded.progress)
  }

  @Test func managerDictionaryOverrides() {
    let manager = ConfigurationManager()
    manager.load([
      "name": "test-gallery",
      "people": ["Alice"],
      "resolutions": [100, 200],
      "progress": false,
    ])
    #expect(manager["name"] as? String == "test-gallery")
    #expect(manager["people"] as? [String] == ["Alice"])
    #expect(manager["resolutions"] as? [Int] == [100, 200])
    #expect(manager["progress"] as? Bool == false)
  }

  @Test func managerOverridesTakePrecedenceOverFile() throws {
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

    #expect(manager["name"] as? String == "from-override")  // dict wins
    #expect(manager["sourceFolder"] as? String == "/file-src")  // file value retained
  }

  @Test func managerReturnsNilForUnknownKey() {
    let manager = ConfigurationManager()
    #expect(manager["totally-unknown-key"] == nil)
  }

  @Test func loadOrThrowMissingFileThrowsTypedError() {
    let manager = ConfigurationManager()
    do {
      _ = try manager.loadOrThrow(file: "/definitely/does/not/exist.json")
      Issue.record("Expected a throw, got success")
    } catch MuninError.configurationFileUnreadable {
      // expected
    } catch {
      Issue.record("Expected .configurationFileUnreadable, got \(error)")
    }
  }

  @Test func loadOrThrowMalformedJSONThrowsTypedError() throws {
    let tmp = URL(
      fileURLWithPath: NSTemporaryDirectory()
    ).appendingPathComponent("munin-bad-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: tmp) }
    try Data("{ this is not json".utf8).write(to: tmp)

    let manager = ConfigurationManager()
    do {
      _ = try manager.loadOrThrow(file: tmp.path)
      Issue.record("Expected a throw, got success")
    } catch MuninError.configurationFileUnreadable {
      // expected
    } catch {
      Issue.record("Expected .configurationFileUnreadable, got \(error)")
    }
  }

  @Test func loadIsSilentOnMissingFile() {
    let manager = ConfigurationManager()
    _ = manager.load(file: "/definitely/does/not/exist.json")
    // Still works with defaults.
    #expect(manager["name"] as? String == "root")
  }
}
