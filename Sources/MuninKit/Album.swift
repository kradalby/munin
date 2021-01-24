//
//  Album.swift
//  g
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Dispatch
import Foundation
import Logging

// swiftlint:disable file_length
struct Album: Hashable, Comparable, Diffable {
  var name: String
  var url: String
  var path: String
  var photos: Set<Photo>
  var albums: Set<Album>
  var keywords: Set<KeywordPointer>
  var people: Set<KeywordPointer>
  var parents: [Parent]

  init(name: String, path: String, parents: [Parent]) {
    self.name = name
    self.path = path
    url = joinPath(path, "index.json")
    photos = []
    albums = []
    keywords = Set()
    people = Set()
    self.parents = parents.sorted()
  }

  enum CodingKeys: String, CodingKey {
    case name
    case url
    case path
    case photos
    case albums
    case keywords
    case people
    case parents
  }
}

extension Album: Encodable {
  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(url, forKey: .url)
    try container.encode(path, forKey: .path)
    try container.encode(Array(keywords).sorted(), forKey: .keywords)
    try container.encode(Array(people).sorted(), forKey: .people)
    try container.encode(parents.sorted(), forKey: .parents)

    var photosContainer = container.nestedUnkeyedContainer(
      forKey: .photos
    )

    try Array(photos).sorted().forEach {
      try photosContainer.encode(
        PhotoInAlbum(
          url: $0.url,
          dateTime: $0.dateTime ?? $0.modifiedDate,
          originalImageURL: $0.originalImageURL,
          scaledPhotos: $0.scaledPhotos.sorted(),
          gps: $0.gps
        )
      )
    }

    var albumsContainer = container.nestedUnkeyedContainer(
      forKey: .albums
    )

    try Array(albums).sorted().forEach {
      let scaledPhotos = $0.firstImageInAlbum()?.scaledPhotos ?? []
      try albumsContainer.encode(
        AlbumInAlbum(url: $0.url, name: $0.name, scaledPhotos: scaledPhotos.sorted()))
    }

    //        var keywordsContainer = container.nestedUnkeyedContainer(
    //            forKey: .keywords)

    //        try keywords.forEach {
    //            try keywordsContainer.encode($0.url)
    //        }
    //
    //        var peopleContainer = container.nestedUnkeyedContainer(
    //            forKey: .people)
    //
    //        try people.forEach {
    //            try peopleContainer.encode($0.url)
    //        }
  }
}

struct PhotoInAlbum: Codable {
  var url: String
  var dateTime: Date
  var originalImageURL: String
  var scaledPhotos: [ScaledPhoto]
  var gps: GPS?
}

struct AlbumInAlbum: Codable {
  var url: String
  var name: String
  var scaledPhotos: [ScaledPhoto]
}

struct Parent: Codable, AutoEquatable, Comparable {
  var name: String
  var url: String

  static func < (lhs: Parent, rhs: Parent) -> Bool {
    return lhs.name < rhs.name
  }
}

extension Parent: CustomStringConvertible {
  var description: String {
    return "Parent: \(name)"
  }
}

extension Album: Decodable {
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    name = try values.decode(String.self, forKey: .name)
    url = try values.decode(String.self, forKey: .url)
    path = try values.decode(String.self, forKey: .path)
    keywords = try values.decode(Set<KeywordPointer>.self, forKey: .keywords)
    people = try values.decode(Set<KeywordPointer>.self, forKey: .people)
    parents = try values.decode([Parent].self, forKey: .parents)

    //        self.photos = try values.decode([Photo].self, forKey: .photos)
    //        self.albums = try values.decode([Album].self, forKey: .albums)

    var photosArray = try values.nestedUnkeyedContainer(forKey: .photos)
    var photos: Set<Photo> = Set<Photo>()
    while !photosArray.isAtEnd {
      let photoInAlbum = try photosArray.decode(PhotoInAlbum.self)
      if let photo = readAndDecodeJsonFile(Photo.self, atPath: photoInAlbum.url) {
        photos.insert(photo)
      }
    }
    self.photos = photos

    var albumsArray = try values.nestedUnkeyedContainer(forKey: .albums)
    var albums: Set<Album> = Set<Album>()
    while !albumsArray.isAtEnd {
      let albumInAlbum = try albumsArray.decode(AlbumInAlbum.self)
      if let album = readAndDecodeJsonFile(Album.self, atPath: albumInAlbum.url) {
        albums.insert(album)
      }
    }
    self.albums = albums

    //        var keywordsArray = try values.nestedUnkeyedContainer(forKey: .keywords)
    //        var keywords: Set<Keyword> = Set<Keyword>()
    //        while (!keywordsArray.isAtEnd) {
    //            let url = try keywordsArray.decode(String.self)
    //            if let keyword = readAndDecodeJsonFile(Keyword.self, atPath: url) {
    //                keywords.insert(keyword)
    //            }
    //        }
    //        self.keywords = keywords
    //
    //        var peopleArray = try values.nestedUnkeyedContainer(forKey: .people)
    //        var people: Set<Keyword> = Set<Keyword>()
    //        while (!peopleArray.isAtEnd) {
    //            let url = try peopleArray.decode(String.self)
    //            if let person = readAndDecodeJsonFile(Keyword.self, atPath: url) {
    //                people.insert(person)
    //            }
    //        }
    //        self.people = people
  }
}

extension Album {
  public func write(ctx: Context, writeJson: Bool, writeImage: Bool) {
    let fileManager = FileManager()
    do {
      try fileManager.createDirectory(
        at: URL(fileURLWithPath: path), withIntermediateDirectories: true)

      log.trace("Writing metadata for album \(name)")
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601

      if writeJson {
        if let encodedData = try? encoder.encode(self) {
          do {
            log.trace("Writing album metadata \(name) to \(url)")
            try encodedData.write(to: URL(fileURLWithPath: url))
          } catch {
            log.error("Could not write album \(name) to \(url) with error: \n\(error)")
          }
        }
      }

      for album in albums {
        album.write(ctx: ctx, writeJson: writeJson, writeImage: writeImage)
      }

      log.trace("Album: \(name) has \(writeImage)")
      for photo in photos {
        photoWriteGroup.enter()
        photoQueue.async {
          photo.write(ctx: ctx, writeJson: writeJson, writeImage: writeImage)
          photoWriteGroup.leave()

          stateQueue.sync {
            ctx.state.incrementPhotosWritten()
          }
        }
      }
      photoWriteGroup.wait()

    } catch {
      log.error("Failed creating directory \(path) with error: \n\(error)")
    }
  }

  public func destroy(ctx: Context) {
    let fileManager = FileManager()
    log.info("Inside: \(name)")
    log.info("Destroying: \(photos)")
    for photo in photos {
      photo.destroy(ctx: ctx)
    }

    for album in albums {
      album.destroy(ctx: ctx)
    }

    do {
      try fileManager.removeItem(atPath: url)
    } catch {
      log.error("Could not remove album json \(name) at path \(url)")
    }

    do {
      try fileManager.removeItem(atPath: path)
    } catch {
      log.error("Could not remove album \(name) at path \(path)")
    }
  }

  public func clean(ctx: Context) {
    let fileManager = FileManager()
    let unrefFiles = unreferencedFiles()
    let unrefFolders = unreferencedFolders()

    log.info("Cleaning album \(name) of unreferenced files: \(unrefFiles)")
    log.info("Cleaning album \(name) of unreferenced folders: \(unrefFiles)")

    for album in albums {
      album.clean(ctx: ctx)
    }

    for file in unrefFiles + unrefFolders {
      do {
        try fileManager.removeItem(at: file)
      } catch {
        log.error("Could not remove album \(name) at path \(path)")
      }
    }
  }

  func expectedFolders() -> [URL] {
    // let folderPath = URL(fileURLWithPath: path)

    let expectedFiles = albums.map { URL(fileURLWithPath: $0.path) }

    return expectedFiles
  }

  func expectedFiles() -> [URL] {
    let jsonURL = URL(fileURLWithPath: url)

    // TODO: replace this with expectedFiles in Keywords, Locations and Stats
    let rootFiles =
      parents.isEmpty
      ? [
        URL(fileURLWithPath: joinPath(path, "stats.json")),
        URL(fileURLWithPath: joinPath(path, "locations.json")),
      ] : []

    // We get the list of files expected for each Photo as that is
    // relevant for this folder directly, we do not recurse to the
    // next album in case of nested albums as that is a folder and
    // not files.
    let expectedFiles = [jsonURL] + photos.flatMap { $0.expectedFiles() } + rootFiles

    return expectedFiles
  }

  func unreferencedFolders() -> [URL] {
    let fileManager = FileManager()
    let expectedFolders = self.expectedFolders()
    let actualFolders = fileManager.directoriesOfDirectory(atPath: path).map {
      URL(fileURLWithPath: joinPath(path, $0))
    }

    return actualFolders.filter { !expectedFolders.contains($0) }
  }

  func unreferencedFiles() -> [URL] {
    let fileManager = FileManager()
    let expectedFiles = self.expectedFiles()
    let actualFiles = fileManager.filesOfDirectory(atPath: path).map {
      URL(fileURLWithPath: joinPath(path, $0))
    }

    return actualFiles.filter { !expectedFiles.contains($0) }
  }

  func missingFiles() -> [URL] {
    let fileManager = FileManager()
    let expectedFiles = self.expectedFiles()
    let actualFiles = fileManager.filesOfDirectory(atPath: path).map {
      URL(fileURLWithPath: joinPath(path, $0))
    }

    return expectedFiles.filter { !actualFiles.contains($0) }
  }

  func copyWithoutChildren() -> Album {
    var newAlbum = Album(name: name, path: path, parents: parents)
    newAlbum.url = url
    newAlbum.photos = []
    newAlbum.albums = []
    newAlbum.keywords = keywords
    newAlbum.people = people

    return newAlbum
  }

  func changedPhotos(_ other: Album) -> Set<Photo> {
    return other.photos.subtracting(photos)
  }

  func changedAlbums(_ other: Album) -> Set<Album> {
    return other.albums.subtracting(albums)
  }

  func firstImageInAlbum() -> Photo? {
    for photo in photos.sorted() where photo.orientation == Orientation.landscape {
      return photo
    }

    for album in albums {
      return album.firstImageInAlbum()
    }

    return nil
  }
}

extension Album: AutoEquatable {
  static func < (lhs: Album, rhs: Album) -> Bool {
    return lhs.name < rhs.name
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(url)
  }
}

extension Album {
  func numberOfPhotos(travers: Bool) -> Int {
    if travers {
      return albums.map { $0.numberOfPhotos(travers: travers) }.reduce(0, +) + photos.count
    }
    return photos.count
  }

  func numberOfAlbums(travers: Bool) -> Int {
    if travers {
      return albums.map { $0.numberOfAlbums(travers: travers) }.reduce(0, +) + albums.count
    }
    return albums.count
  }

  func flattenPhotos() -> Set<Photo> {
    // swiftlint:disable identifier_name
    return photos.union(
      albums.map { $0.flattenPhotos() }.reduce(Set()) { x, y in
        x.union(y)
      })
  }

  func isEmpty(travers: Bool) -> Bool {
    for album in albums {
      if !album.isEmpty(travers: travers) {
        return false
      }
    }
    return photos.isEmpty
  }
}

extension Album: CustomStringConvertible {
  var description: String {
    // let photos = Array(self.photos.map { String(describing: $0) }).joined(separator: "\n  ")
    return "Album: \(name), photos: \(String(describing: photos))"
  }
}

// swiftlint:disable cyclomatic_complexity
// swiftlint:disable function_body_length
func readStateFromInputDirectory(
  ctx: Context,
  atPath: String,
  outPath: String,
  name: String,
  parents: [Parent]
) -> Album {
  log.trace("Creating album from path: \(joinPath(atPath))")

  var album = Album(name: name, path: joinPath(outPath, urlifyName(name)), parents: parents)
  let parent = Parent(name: album.name, url: album.url)
  var newParents = parents
  newParents.append(parent)

  let directories = FileManager.default.directoriesOfDirectory(atPath: joinPath(atPath))
  for directory in directories {
    let childAlbum = readStateFromInputDirectory(
      ctx: ctx,
      atPath: joinPath(atPath, directory),
      outPath: joinPath(outPath, name),
      name: directory,
      parents: newParents
    )
    album.albums.insert(childAlbum)
    album.keywords = album.keywords.union(childAlbum.keywords)
    album.people = album.people.union(childAlbum.people)
  }

  var photos = [Photo]()
  let files = FileManager.default.filesOfDirectoryByExtensions(
    atPath: joinPath(atPath), extensions: ctx.config.fileExtentions
  )
  for file in files {
    let fileNameWithoutExt = fileNameWithoutExtension(
      atPath: joinPath(atPath, file))
    if let fileExtension = fileExtension(atPath: joinPath(atPath, file)) {
      photoToReadGroup.enter()
      photoQueue.async {
        let maybePhoto = readPhotoFromPath(
          atPath: joinPath(atPath, file),
          outPath: joinPath(outPath, urlifyName(name)),
          name: fileNameWithoutExt,
          fileExtension: fileExtension,
          parents: newParents,
          ctx: ctx
        )

        stateQueue.sync {
          if let photo = maybePhoto {
            if photo.include() {
              photos.append(photo)
            } else {
              log.debug("Photo \(photo.name) included NO_HUGIN keyword, ignoring...")
            }
          }

          ctx.state.updatePhotosToWrite(name: joinPath(atPath, file))

        }
        photoToReadGroup.leave()
      }

    } else {
      log.warning(
        "File found, but it was not a photo, path: \(joinPath(atPath, file))")
    }
  }
  photoToReadGroup.wait()

  // Ensure that we have a stable order before building next/previous map.
  photos.sort(by: { $0.dateTime ?? Date.distantPast < $1.dateTime ?? Date.distantPast })

  for (index, photo) in photos.enumerated() {
    let previous = photos.index(before: index)
    let next = photos.index(after: index)
    if previous == -1 {
      photos[index].previous = photos[photos.count - 1].url

    } else {
      photos[index].previous = photos[photos.index(before: index)].url
    }
    if next == photos.count {
      photos[index].next = photos[0].url
    } else {
      photos[index].next = photos[photos.index(after: index)].url
    }

    album.photos.insert(photos[index])

    album.keywords = album.keywords.union(photo.keywords)
    album.people = album.people.union(photo.people)
  }

  return album
}

func readStateFromOutputDirectory(indexFileAtPath: String) -> Album? {
  return readAndDecodeJsonFile(Album.self, atPath: indexFileAtPath)
}
