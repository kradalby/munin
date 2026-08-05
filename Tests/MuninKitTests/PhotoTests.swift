import Foundation
import Testing

@testable import MuninKit

@Suite(.serialized)
final class PhotoTests {
  let photoPath = "example/album/2017/2017-12-22 Juleferie/20171222-132846-20171222-IMG_5259.jpg"
  let photo2Path = "example/album/2017/2017-12-22 Juleferie/20171224-165120-20171224-IMG_5284.jpg"
  let photo3Path = "example/album/2017/2017-12-19 Aarhus/20171219-143810-20171219-IMG_5246-2.jpg"
  let photo4Path = "example/album/Misc/portrait_mm.jpeg"
  let outPath = "example/content/"
  let configPath = "example/munin.json"

  init() {
    VIPSSetup.ensure()
  }

  @Test func expectedValuesRead() throws {
    let manager = ConfigurationManager()
    manager.load(file: configPath, relativeFrom: .customPath(""))
    let config = GalleryConfiguration(manager)

    let ctx = Context(config: config)

    let photo = try #require(
      readPhotoFromPath(
        atPath: photoPath, outPath: outPath, name: "test", fileExtension: "jpg",
        parents: [], ctx: ctx
      )
    )
    let photo2 = try #require(
      readPhotoFromPath(
        atPath: photo2Path, outPath: outPath, name: "test2", fileExtension: "jpg",
        parents: [], ctx: ctx
      )
    )
    let photo3 = try #require(
      readPhotoFromPath(
        atPath: photo3Path, outPath: outPath, name: "test3", fileExtension: "jpg",
        parents: [], ctx: ctx
      )
    )
    // Rotation issue photo
    let photo4 = try #require(
      readPhotoFromPath(
        atPath: photo4Path, outPath: outPath, name: "test4", fileExtension: "jpeg",
        parents: [], ctx: ctx
      )
    )

    #expect(photo.name == "test")
    #expect(photo.url.string == "example/content/test.json")
    #expect(photo.scaledPhotos.count == 7)
    #expect(photo.aperture == 2.64386)
    #expect(photo.orientation == .landscape)
    #expect(photo.people.map { $0.name } == ["Angel Dalby"])
    #expect(
      photo.keywords.map { $0.name }.sorted()
        == ["Jul", "Aspargesgården", "Christmas", "Tjodalyng", "2017", "Norway", "Vestfold"]
          .sorted())

    #expect(photo2.name == "test2")
    #expect(photo2.url.string == "example/content/test2.json")
    #expect(photo2.scaledPhotos.count == 7)
    #expect(photo2.aperture == 2.97085)
    #expect(photo2.orientation == .landscape)
    #expect(photo2.people.map { $0.name } == ["Angel Dalby"])
    #expect(
      photo2.keywords.map { $0.name }.sorted()
        == ["Aspargesgården", "Tjodalyng", "Norway", "Jul", "2017", "Vestfold", "Christmas"]
          .sorted())

    #expect(photo3.name == "test3")
    #expect(photo3.url.string == "example/content/test3.json")
    #expect(photo3.scaledPhotos.count == 7)
    #expect(photo3.aperture == 4.64386)
    #expect(photo3.orientation == .portrait)
    #expect(photo3.people.map { $0.name } == [])
    #expect(
      photo3.keywords.map { $0.name }.sorted()
        == ["Denmark", "2017", "Århus", "Central Denmark Region", "DK", "Street art"].sorted())

    #expect(photo4.name == "test4")
    #expect(photo4.url.string == "example/content/test4.json")
    #expect(photo4.scaledPhotos.count == 8)
    #expect(photo4.aperture == 1.696)
    #expect(photo4.orientation == .portrait)
    #expect(photo4.people.map { $0.name }.sorted() == [])
    #expect(
      photo4.keywords.map { $0.name }.sorted() == ["Martin Peter Meuche", "Spring"].sorted())
  }

  @Test func expectedFiles() throws {
    let manager = ConfigurationManager()
    manager.load(file: configPath, relativeFrom: .customPath(""))
    let config = GalleryConfiguration(manager)

    let ctx = Context(config: config)

    let photo = try #require(
      readPhotoFromPath(
        atPath: photoPath, outPath: outPath, name: "test", fileExtension: "jpg",
        parents: [], ctx: ctx
      )
    )

    let cwd = FileManager.default.currentDirectoryPath
    let expectedFiles = [
      "test.json", "test_180.jpg", "test_220.jpg",
      "test_340.jpg", "test_576.jpg", "test_768.jpg",
      "test_992.jpg", "test_1200.jpg", "test_original.jpg",
    ].map { "\(cwd)/example/content/\($0)" }.sorted()
    let actualFiles = photo.expectedFiles.map { $0.path }.sorted()

    #expect(actualFiles == expectedFiles)
  }

  @Test func sortWithDateTimes() {
    let unsorted = [
      Photo(name: "atest3", dateTime: Date(timeIntervalSince1970: 1_610_473_000)),
      Photo(name: "xtest1", dateTime: Date(timeIntervalSince1970: 1_610_470_000)),
      Photo(name: "btest2", dateTime: Date(timeIntervalSince1970: 1_610_472_000)),
    ]

    #expect(unsorted.map { $0.name } == ["atest3", "xtest1", "btest2"])
    #expect(unsorted.sorted().map { $0.name } == ["xtest1", "btest2", "atest3"])
  }

  @Test func sortWithNoDateTimes() {
    let unsorted = [
      Photo(name: "btest3"),
      Photo(name: "ctest1"),
      Photo(name: "atest2"),
    ]

    #expect(unsorted.map { $0.name } == ["btest3", "ctest1", "atest2"])
    #expect(unsorted.sorted().map { $0.name } == ["atest2", "btest3", "ctest1"])
  }

  @Test func sortWithMixDateTimesAndName() {
    let unsorted = [
      Photo(name: "test5"),
      Photo(name: "test6"),
      Photo(name: "test7", dateTime: Date(timeIntervalSince1970: 1_610_472_000)),
    ]

    #expect(unsorted.map { $0.name } == ["test5", "test6", "test7"])
    #expect(unsorted.sorted().map { $0.name } == ["test7", "test5", "test6"])
  }
}
