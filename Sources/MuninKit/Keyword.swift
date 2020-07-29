import Foundation
import Logging

struct Keyword: Hashable, Comparable {
  var name: String
  var url: String
  var photos: Set<Photo>

  init(name: String, url: String) {
    self.name = name
    self.url = url
    photos = []
  }

  enum CodingKeys: String, CodingKey {
    case name
    case url
    case photos
    //        case path
  }
}

extension Keyword: Encodable {
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(url, forKey: .url)

    var photosContainer = container.nestedUnkeyedContainer(
      forKey: .photos
    )

    try photos.forEach {
      try photosContainer.encode(
        PhotoInAlbum(
          url: $0.url,
          dateTime: $0.dateTime ?? $0.modifiedDate,
          originalImageURL: $0.originalImageURL,
          scaledPhotos: $0.scaledPhotos,
          gps: $0.gps
        )
      )
    }
  }
}

extension Keyword: Decodable {
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    name = try values.decode(String.self, forKey: .name)
    url = try values.decode(String.self, forKey: .url)

    // Here we will end up with the same picture twice in memory, is that a problem?
    var photosArray = try values.nestedUnkeyedContainer(forKey: .photos)
    var photos: Set<Photo> = Set<Photo>()
    while !photosArray.isAtEnd {
      let photoInAlbum = try photosArray.decode(PhotoInAlbum.self)
      if let photo = readAndDecodeJsonFile(Photo.self, atPath: photoInAlbum.url) {
        photos.insert(photo)
      }
    }
    self.photos = photos
  }
}

extension Keyword: AutoEquatable {
  static func < (lhs: Keyword, rhs: Keyword) -> Bool {
    return lhs.name < rhs.name
  }
}

extension Keyword {
  func write(ctx: Context) {
    let fileManager = FileManager()
    let path = URL(fileURLWithPath: url).deletingLastPathComponent()
    do {
      try fileManager.createDirectory(at: path, withIntermediateDirectories: true)

      log.trace("Writing metadata for \(type(of: self)) \(name)")
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601

      if let encodedData = try? encoder.encode(self) {
        do {
          log.trace("Writing \(type(of: self)) metadata \(name) to \(url)")
          try encodedData.write(to: URL(fileURLWithPath: url))
        } catch {
          log.error("Could not write \(type(of: self)) \(name) to \(url) with error: \n\(error)")
        }
      }
    } catch {
      log.error("Failed creating directory \(path.absoluteString) with error: \n\(error)")
    }
  }
}

func buildKeywordsFromAlbum(album: Album) -> [Keyword] {
  var temporary: [String: Keyword] = [:]

  for photo in album.flattenPhotos() {
    for keywordPointer in photo.keywords {
      if temporary.keys.contains(keywordPointer.name) {
        temporary[keywordPointer.name]!.photos.insert(photo)
      } else {
        var keyword = Keyword(name: keywordPointer.name, url: keywordPointer.url)
        keyword.photos.insert(photo)
        temporary[keywordPointer.name] = keyword
      }
    }
  }
  return temporary.values.map { $0 }
}

func buildPeopleFromAlbum(album: Album) -> [Keyword] {
  var temporary: [String: Keyword] = [:]

  for photo in album.flattenPhotos() {
    for keywordPointer in photo.people {
      if temporary.keys.contains(keywordPointer.name) {
        temporary[keywordPointer.name]!.photos.insert(photo)
      } else {
        var keyword = Keyword(name: keywordPointer.name, url: keywordPointer.url)
        keyword.photos.insert(photo)
        temporary[keywordPointer.name] = keyword
      }
    }
  }
  return temporary.values.map { $0 }
}

struct KeywordPointer: Hashable, Comparable, Codable {
  var name: String
  var url: String

  static func < (lhs: KeywordPointer, rhs: KeywordPointer) -> Bool {
    return lhs.name < rhs.name
  }

  static func == (lhs: KeywordPointer, rhs: KeywordPointer) -> Bool {
    guard lhs.name == rhs.name else { return false }
    guard lhs.url == rhs.url else { return false }

    return true
  }

  static func == (lhs: Keyword, rhs: KeywordPointer) -> Bool {
    guard lhs.name == rhs.name else { return false }
    guard lhs.url == rhs.url else { return false }

    return true
  }

  static func == (lhs: KeywordPointer, rhs: Keyword) -> Bool {
    return rhs == lhs
  }
}
