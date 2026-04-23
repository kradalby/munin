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
struct Album: Hashable, Comparable, Diffable, Sendable {
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
      let scaledPhotos = $0.landscapeCoverPhoto()?.scaledPhotos ?? []
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

struct PhotoInAlbum: Codable, Sendable {
  var url: String
  var dateTime: Date
  var originalImageURL: String
  var scaledPhotos: [ScaledPhoto]
  var gps: GPS?
}

struct AlbumInAlbum: Codable, Sendable {
  var url: String
  var name: String
  var scaledPhotos: [ScaledPhoto]
}

struct Parent: Codable, AutoEquatable, Comparable, Sendable {
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
  /// Write this album (and recursively its sub-albums and photos) to disk.
  ///
  /// Photo writes within a single album execute in parallel via
  /// `withThrowingTaskGroup`, bounded by an `AsyncSemaphore` sized from
  /// `ctx.config.concurrency`. Sub-albums are written sequentially (each
  /// handles its own photo parallelism).
  public func write(
    ctx: Context,
    writeJson: Bool,
    writeImage: Bool,
    sem: AsyncSemaphore? = nil
  ) async throws {
    let sem = sem ?? AsyncSemaphore(value: max(ctx.config.concurrency, 1))
    let fileManager = FileManager()
    do {
      try fileManager.createDirectory(
        at: URL(fileURLWithPath: path), withIntermediateDirectories: true)
    } catch {
      ctx.log.error("Failed creating directory \(path) with error: \n\(error)")
      return
    }

    ctx.log.trace("Writing metadata for album \(name)")
    if writeJson {
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      if let encodedData = try? encoder.encode(self) {
        do {
          ctx.log.trace("Writing album metadata \(name) to \(url)")
          try encodedData.write(to: URL(fileURLWithPath: url))
        } catch {
          ctx.log.error("Could not write album \(name) to \(url) with error: \n\(error)")
        }
      }
    }

    for album in albums {
      try await album.write(
        ctx: ctx, writeJson: writeJson, writeImage: writeImage, sem: sem)
    }

    ctx.log.trace("Album: \(name) has \(writeImage)")
    try await withThrowingTaskGroup(of: Void.self) { group in
      for photo in photos {
        await sem.wait()
        group.addTask {
          photo.write(ctx: ctx, writeJson: writeJson, writeImage: writeImage)
          ctx.state.incrementPhotosWritten()
          await sem.signal()
        }
      }
      try await group.waitForAll()
    }
  }

  public func destroy(ctx: Context) {
    let fileManager = FileManager()
    ctx.log.info("Inside: \(name)")
    ctx.log.info("Destroying: \(photos)")
    for photo in photos {
      photo.destroy(ctx: ctx)
    }

    for album in albums {
      album.destroy(ctx: ctx)
    }

    do {
      try fileManager.removeItem(atPath: url)
    } catch {
      ctx.log.error("Could not remove album json \(name) at path \(url)")
    }

    do {
      try fileManager.removeItem(atPath: path)
    } catch {
      ctx.log.error("Could not remove album \(name) at path \(path)")
    }
  }

  public func clean(ctx: Context) {
    let fileManager = FileManager()
    let unrefFiles = unreferencedFiles()
    let unrefFolders = unreferencedFolders()

    ctx.log.info("Cleaning album \(name) of unreferenced files: \(unrefFiles)")
    ctx.log.info("Cleaning album \(name) of unreferenced folders: \(unrefFiles)")

    for album in albums {
      album.clean(ctx: ctx)
    }

    for file in unrefFiles + unrefFolders {
      do {
        try fileManager.removeItem(at: file)
      } catch {
        ctx.log.error("Could not remove album \(name) at path \(path)")
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
        URL(fileURLWithPath: joinPath(path, "locations.json"))
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

  func landscapeCoverPhoto() -> Photo? {
    for photo in photos.sorted() where photo.orientation == Orientation.landscape {
      return photo
    }

    for album in albums.sorted() {
      if let photo = album.landscapeCoverPhoto() {
        return photo
      }
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

/// Recursively read an input directory into an `Album` tree.
///
/// Photos within a single directory are read in parallel via
/// `withThrowingTaskGroup`, bounded by an `AsyncSemaphore` sized from
/// `ctx.config.concurrency` so we never have more than N VIPS/EXIF reads in
/// flight at once. Sub-album directories are traversed sequentially (they in
/// turn parallelise their own photo reads).
func readStateFromInputDirectory(
  ctx: Context,
  atPath: String,
  outPath: String,
  name: String,
  parents: [Parent],
  sem: AsyncSemaphore? = nil
) async throws -> Album {
  let sem = sem ?? AsyncSemaphore(value: max(ctx.config.concurrency, 1))
  ctx.log.trace("Creating album from path: \(joinPath(atPath))")

  var album = Album(name: name, path: joinPath(outPath, urlifyName(name)), parents: parents)
  let parent = Parent(name: album.name, url: album.url)
  var newParents = parents
  newParents.append(parent)
  let capturedParents = newParents

  // Sub-albums (depth-first).
  let directories = FileManager.default.directoriesOfDirectory(atPath: joinPath(atPath))
  for directory in directories {
    let childAlbum = try await readStateFromInputDirectory(
      ctx: ctx,
      atPath: joinPath(atPath, directory),
      outPath: joinPath(outPath, name),
      name: directory,
      parents: capturedParents,
      sem: sem
    )
    album.albums.insert(childAlbum)
    album.keywords = album.keywords.union(childAlbum.keywords)
    album.people = album.people.union(childAlbum.people)
  }

  // Parallel photo reads with bounded concurrency.
  let files = FileManager.default.filesOfDirectoryByExtensions(
    atPath: joinPath(atPath), extensions: ctx.config.fileExtensions
  )
  let albumOutPath = joinPath(outPath, urlifyName(name))

  let readPhotos: [Photo] = try await withThrowingTaskGroup(of: Photo?.self) { group in
    for file in files {
      let filePath = joinPath(atPath, file)
      let fileNameWithoutExt = fileNameWithoutExtension(atPath: filePath)
      guard let fileExt = fileExtension(atPath: filePath) else {
        ctx.log.warning("File found, but it was not a photo, path: \(filePath)")
        continue
      }

      await sem.wait()
      group.addTask {
        let photo = readPhotoFromPath(
          atPath: filePath,
          outPath: albumOutPath,
          name: fileNameWithoutExt,
          fileExtension: fileExt,
          parents: capturedParents,
          ctx: ctx
        )
        ctx.state.updatePhotosToWrite(name: filePath)
        await sem.signal()

        guard let photo else { return nil }
        if !photo.include() {
          ctx.log.debug("Photo \(photo.name) included NO_HUGIN keyword, ignoring...")
          return nil
        }
        return photo
      }
    }

    var collected: [Photo] = []
    for try await result in group {
      if let photo = result {
        collected.append(photo)
      }
    }
    return collected
  }

  // Sort by capture time, then wire up next/previous navigation.
  var photos = readPhotos.sorted {
    ($0.dateTime ?? .distantPast) < ($1.dateTime ?? .distantPast)
  }
  let photoCount = photos.count
  for index in photos.indices {
    let previousIndex = index == 0 ? photoCount - 1 : index - 1
    let nextIndex = index == photoCount - 1 ? 0 : index + 1
    photos[index].previous = photos[previousIndex].url
    photos[index].next = photos[nextIndex].url
  }

  for photo in photos {
    album.photos.insert(photo)
    album.keywords = album.keywords.union(photo.keywords)
    album.people = album.people.union(photo.people)
  }

  return album
}

func readStateFromOutputDirectory(indexFileAtPath: String) -> Album? {
  return readAndDecodeJsonFile(Album.self, atPath: indexFileAtPath)
}
