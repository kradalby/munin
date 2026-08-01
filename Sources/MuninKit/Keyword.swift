import Foundation
import Logging
import SystemPackage

struct Keyword: Hashable, Comparable, Sendable {
  var name: String
  var url: FilePath
  var photos: Set<Photo>

  init(name: String, url: String) {
    self.init(name: name, url: FilePath(url))
  }

  init(name: String, url: FilePath) {
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

    try Array(photos).sorted().forEach {
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
    url = try values.decode(FilePath.self, forKey: .url)

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

extension Keyword {
  /// Name, then url — the same total order as ``KeywordPointer/<(_:_:)``.
  ///
  /// `buildKeywordsFromAlbum` keys its accumulator by name, so the array
  /// this orders happens to hold canonically-distinct names today and the
  /// tie-break never decides anything there. It is here so the comparator
  /// is a strict total order over any `Keyword` values, not only over the
  /// ones one current caller happens to build: a name-only comparison ties
  /// on `Håkon` spelled NFC and NFD, and `sorted()` is stable, so a tie
  /// silently inherits `Set`/`Dictionary` iteration order — which comes
  /// from the per-process randomised hash seed. See `OrderingTotalityTests`.
  static func < (lhs: Keyword, rhs: Keyword) -> Bool {
    if lhs.name != rhs.name {
      return lhs.name < rhs.name
    }
    return canonicalThenBytewiseLess(lhs.url.string, rhs.url.string)
  }
}

extension Keyword {
  func write(ctx: Context) throws {
    let parentDir = url.removingLastComponent()
    do {
      try POSIX.createDirectory(parentDir)
    } catch {
      throw MuninError.directoryCreationFailed(
        path: parentDir.string, underlying: String(describing: error))
    }

    ctx.log.trace("Writing metadata for \(type(of: self)) \(name)")
    let encoder = MuninJSON.encoder()

    let encodedData: Data
    do {
      encodedData = try encoder.encode(self)
    } catch {
      throw MuninError.metadataWriteFailed(
        path: url.string, underlying: String(describing: error))
    }

    ctx.log.trace("Writing \(type(of: self)) metadata \(name) to \(url)")
    try FileIO.writeAtomic(encodedData, to: url)
  }
}

extension Keyword: CustomStringConvertible {
  var description: String {
    return "Keyword: \(name), photos: \(String(describing: photos))"
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
  return temporary.values.map { $0 }.sorted()
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
  return temporary.values.map { $0 }.sorted()
}

struct KeywordPointer: Hashable, Comparable, Codable, Sendable {
  var name: String
  var url: FilePath

  init(name: String, url: String) {
    self.name = name
    self.url = FilePath(url)
  }

  init(name: String, url: FilePath) {
    self.name = name
    self.url = url
  }

  /// Name, then url. `KeywordPointer` equality covers both fields, so two
  /// canonically-equivalent spellings of one keyword survive side by side
  /// in a `Set` (their urls differ byte-wise, and `FilePath` compares
  /// bytes) while `name` alone cannot order them.
  static func < (lhs: KeywordPointer, rhs: KeywordPointer) -> Bool {
    if lhs.name != rhs.name {
      return lhs.name < rhs.name
    }
    return canonicalThenBytewiseLess(lhs.url.string, rhs.url.string)
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

extension KeywordPointer: CustomStringConvertible {
  var description: String {
    return "KeywordPointer: \(name)"
  }
}
