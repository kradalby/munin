//
//  Locations.swift
//  MuninPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 18/03/2018.
//

import Foundation
import Logging
import SystemPackage

public struct Locations: Codable, Sendable {
  var locations: [Location]

  init(gallery: Gallery) {
    locations = locationsFromAlbum(album: gallery.input)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(Array(locations).sorted(), forKey: .locations)
  }

  public func write(ctx: Context) throws {
    ctx.log.info("Writing locations")
    let path = FilePath(joinPath(ctx.config.outputPath, ctx.config.name, "locations.json"))

    let encoder = MuninJSON.encoder()
    let encodedData: Data
    do {
      encodedData = try encoder.encode(self)
    } catch {
      throw MuninError.metadataWriteFailed(
        path: path.string, underlying: String(describing: error))
    }

    ctx.log.trace("Writing locations to json to \(path)")
    try FileIO.writeAtomic(encodedData, to: path)
  }
}

struct Location: Codable, Comparable, Sendable {
  var url: FilePath
  var gps: GPS
  var scaledPhotos: [ScaledPhoto]
}

extension Location {
  /// `locationsFromAlbum` walks `Set<Photo>` and `Set<Album>` and appends,
  /// so the array handed to `sorted()` is already in hash-seed order; a
  /// tie here goes straight into `locations.json`.
  static func < (lhs: Location, rhs: Location) -> Bool {
    return canonicalThenBytewiseLess(lhs.url.string, rhs.url.string)
  }
}

func locationsFromAlbum(album: Album) -> [Location] {
  var locations: [Location] = []

  for photo in album.photos {
    if let gps = photo.gps {
      let location = Location(
        url: photo.url,
        gps: gps,
        scaledPhotos: photo.scaledPhotos
      )

      locations.append(location)
    }
  }

  for nestedAlbum in album.albums {
    locations.append(contentsOf: locationsFromAlbum(album: nestedAlbum))
  }

  return locations
}
