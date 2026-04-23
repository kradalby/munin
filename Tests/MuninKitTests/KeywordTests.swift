import Foundation
import Testing

@testable import MuninKit

@Suite(.serialized)
final class KeywordTests {
  let albumPath = "example/album/"
  let outPath = "example/content/"
  let configPath = "example/munin.json"
  let peoplePath = "example/people.json"
  let config: GalleryConfiguration
  let ctx: Context

  init() {
    VIPSSetup.ensure()
    let manager = ConfigurationManager()
    manager
      .load(file: configPath, relativeFrom: .customPath(""))
      .load(["progress": false])
    self.config = GalleryConfiguration(manager)
    self.ctx = Context(config: config)
  }

  @Test func buildKeywordsFromAlbumBuildsExpectedSet() async throws {
    let album = try await readStateFromInputDirectory(
      ctx: ctx, atPath: albumPath, outPath: outPath, name: "test", parents: [])

    let keywords = buildKeywordsFromAlbum(album: album)

    #expect(keywords.count == 79)

    let strings = keywords.map { $0.name }

    #expect(strings.contains("Midtøsten"))
    #expect(strings.contains("Århus"))
    #expect(strings.contains("Tel Aviv District"))
    #expect(strings.contains("Aishling Cooke"))
  }

  @Test func peopleFilesMergesExplicitAndConfigured() {
    let manager = ConfigurationManager()
    manager.load([
      "people": ["Man Person", "BoJo Trump", "Ola Nordmann"],
      "peopleFiles": [peoplePath],
    ])
    let merged = GalleryConfiguration(manager)

    #expect(merged.allPeople.count == 4)
  }

  @Test func peopleFilesAutoPicksUpFromDefaultConfig() {
    #expect(config.allPeople.count == 16)
  }
}
