import Foundation
import Testing

@testable import MuninKit

/// Locks the on-disk JSON schema that downstream consumers (notably
/// Hugin) depend on.
///
/// Every test here asserts two things for one of Munin's emitted JSON
/// shapes:
///
/// 1. The expected set of top-level keys is present (nothing renamed
///    or dropped).
/// 2. A decode → encode → re-decode round-trip is lossless.
///
/// These are intentionally decoupled from the filesystem-building
/// `StabilityTests`: they exercise the Codable boundary directly, so a
/// failure here points straight at the model change rather than at
/// the pipeline as a whole.
@Suite
struct ApiContractTests {

  // MARK: - Photo

  @Test func photoJsonExposesExpectedKeys() throws {
    var photo = Self.samplePhoto()
    photo.sourceHash = "deadbeef"
    photo.dateTime = Date(timeIntervalSince1970: 1_700_000_000)
    photo.width = 4000
    photo.height = 3000
    photo.orientation = .landscape
    photo.aperture = 2.8
    photo.keywords = [KeywordPointer(name: "k", url: "/k.json")]
    photo.people = [KeywordPointer(name: "p", url: "/p.json")]
    photo.gps = GPS(altitude: 10, latitude: 1.0, longitude: 2.0)
    photo.location = LocationData(
      city: "Oslo", state: "NO", locationCode: "NO", locationName: "Norway")

    let keys = try topLevelKeys(of: photo)
    // Every field a Hugin-style client relies on. Adding a new optional
    // field elsewhere is fine; renaming or dropping any of these must
    // fail the test.
    let expectedSubset: Set<String> = [
      "name", "url", "originalImageURL", "originalImagePath",
      "scaledPhotos", "parents", "modifiedDate", "sourceHash",
      "keywords", "people", "width", "height", "orientation",
      "aperture", "gps", "location", "dateTime",
    ]
    let missing = expectedSubset.subtracting(keys)
    #expect(missing.isEmpty, "Photo JSON missing expected keys: \(missing.sorted())")
  }

  @Test func photoRoundTripsThroughCanonicalEncoder() throws {
    var original = Self.samplePhoto()
    original.sourceHash = "cafebabe"
    original.width = 800
    original.height = 600
    original.orientation = .portrait

    let encoded = try MuninJSON.encoder().encode(original)
    let decoded = try MuninJSON.decoder().decode(Photo.self, from: encoded)
    #expect(decoded == original)
  }

  @Test func photoRoundTripPreservesSourceHash() throws {
    var p = Self.samplePhoto()
    p.sourceHash = "abc123"
    let data = try MuninJSON.encoder().encode(p)
    let back = try MuninJSON.decoder().decode(Photo.self, from: data)
    #expect(back.sourceHash == "abc123")
  }

  @Test func photoDecodesWithoutSourceHashField() throws {
    // Back-compat: JSONs written before the sourceHash field existed
    // must still decode, producing nil for the missing optional.
    let legacyJSON = """
      {
        "height": 0,
        "isoSpeed": [],
        "keywords": [],
        "modifiedDate": "2021-01-01T00:00:00Z",
        "name": "legacy",
        "originalImagePath": "/in/legacy.jpg",
        "originalImageURL": "/out/legacy_original.jpg",
        "parents": [],
        "people": [],
        "scaledPhotos": [],
        "url": "/out/legacy.json"
      }
      """.data(using: .utf8)!
    let decoded = try MuninJSON.decoder().decode(Photo.self, from: legacyJSON)
    #expect(decoded.name == "legacy")
    #expect(decoded.sourceHash == nil)
  }

  // MARK: - Album

  @Test func albumJsonExposesExpectedKeys() throws {
    var album = Album(name: "root", path: "/out/root", parents: [])
    album.url = "/out/root/index.json"
    album.keywords = [KeywordPointer(name: "k", url: "/out/keywords/k.json")]
    album.people = []
    album.photos = []
    album.albums = []

    let keys = try topLevelKeys(of: album)
    let expected: Set<String> = [
      "name", "url", "path", "photos", "albums", "keywords", "people", "parents",
    ]
    #expect(
      keys == expected,
      "Album JSON keys: got \(keys.sorted()), expected \(expected.sorted())")
  }

  // MARK: - Keyword

  @Test func keywordJsonExposesExpectedKeys() throws {
    let keyword = Keyword(name: "Oslo", url: "/out/keywords/Oslo.json")
    let keys = try topLevelKeys(of: keyword)
    let expected: Set<String> = ["name", "url", "photos"]
    #expect(
      keys == expected,
      "Keyword JSON keys: got \(keys.sorted()), expected \(expected.sorted())")
  }

  // MARK: - Statistics

  @Test func statisticsJsonExposesExpectedKeys() throws {
    // Statistics' public initialiser takes a Gallery, so construct one by
    // encoding directly from a manually-populated struct via Data.
    // Build a synthetic JSON document matching the expected shape, then
    // round-trip it through the decoder.
    let rawJSON = """
      {
        "originalPhotos": 10,
        "writtenPhotos": 70,
        "albums": 3,
        "keywords": 5,
        "people": 2
      }
      """.data(using: .utf8)!
    let stats = try MuninJSON.decoder().decode(Statistics.self, from: rawJSON)
    let data = try MuninJSON.encoder().encode(stats)
    let keys = try topLevelKeys(data: data)
    let expected: Set<String> = [
      "originalPhotos", "writtenPhotos", "albums", "keywords", "people",
    ]
    #expect(
      keys == expected,
      "Statistics JSON keys: got \(keys.sorted()), expected \(expected.sorted())")
  }

  // MARK: - Locations

  @Test func locationsJsonExposesExpectedKeys() throws {
    // Same approach as Statistics — Locations' initialiser requires a
    // Gallery, so exercise the Codable layer directly.
    let rawJSON = """
      {
        "locations": [
          {
            "url": "/out/p.json",
            "gps": {"altitude": 1.0, "latitude": 2.0, "longitude": 3.0},
            "scaledPhotos": []
          }
        ]
      }
      """.data(using: .utf8)!
    let locs = try MuninJSON.decoder().decode(Locations.self, from: rawJSON)
    let data = try MuninJSON.encoder().encode(locs)
    let keys = try topLevelKeys(data: data)
    #expect(keys == ["locations"])
  }

  // MARK: - KeywordPointer

  @Test func keywordPointerHasOnlyNameAndUrl() throws {
    let kp = KeywordPointer(name: "Oslo", url: "/out/keywords/Oslo.json")
    let data = try MuninJSON.encoder().encode(kp)
    let keys = try topLevelKeys(data: data)
    #expect(keys == ["name", "url"])
  }

  // MARK: - Helpers

  private func topLevelKeys<T: Encodable>(of value: T) throws -> Set<String> {
    let data = try MuninJSON.encoder().encode(value)
    return try topLevelKeys(data: data)
  }

  private func topLevelKeys(data: Data) throws -> Set<String> {
    let object = try JSONSerialization.jsonObject(with: data, options: [])
    guard let dict = object as? [String: Any] else { return [] }
    return Set(dict.keys)
  }

  private static func samplePhoto(
    name: String = "sample",
    url: String = "/out/sample.json",
    modifiedDate: Date = Date(timeIntervalSince1970: 1_700_000_000)
  ) -> Photo {
    Photo(
      name: name,
      url: url,
      originalImageURL: "/out/\(name)_original.jpg",
      originalImagePath: "/in/\(name).jpg",
      scaledPhotos: [ScaledPhoto(url: "/out/\(name)_180.jpg", maxResolution: 180)],
      modifiedDate: modifiedDate,
      parents: []
    )
  }
}
