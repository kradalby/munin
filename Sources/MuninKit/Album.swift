//
//  Album.swift
//  g
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Foundation
import SystemPackage

struct Album: Hashable, Comparable, Sendable {
  var name: String
  var url: FilePath
  var path: FilePath
  var photos: Set<Photo>
  var albums: Set<Album>
  var keywords: Set<KeywordPointer>
  var people: Set<KeywordPointer>
  var parents: [Parent]

  init(name: String, path: String, parents: [Parent]) {
    self.init(name: name, path: FilePath(path), parents: parents)
  }

  init(name: String, path: FilePath, parents: [Parent]) {
    self.name = name
    self.path = path
    url = path.appending("index.json")
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
  }
}

struct PhotoInAlbum: Codable, Sendable {
  var url: FilePath
  var dateTime: Date
  var originalImageURL: FilePath
  var scaledPhotos: [ScaledPhoto]
  var gps: GPS?
}

struct AlbumInAlbum: Codable, Sendable {
  var url: FilePath
  var name: String
  var scaledPhotos: [ScaledPhoto]
}

struct Parent: Codable, Equatable, Comparable, Sendable {
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
    url = try values.decode(FilePath.self, forKey: .url)
    path = try values.decode(FilePath.self, forKey: .path)
    keywords = try values.decode(Set<KeywordPointer>.self, forKey: .keywords)
    people = try values.decode(Set<KeywordPointer>.self, forKey: .people)
    parents = try values.decode([Parent].self, forKey: .parents)

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
  }
}

extension Album {
  static func < (lhs: Album, rhs: Album) -> Bool {
    return lhs.name < rhs.name
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(url)
  }
}

extension Album: CustomStringConvertible {
  var description: String {
    return "Album: \(name), photos: \(String(describing: photos))"
  }
}
