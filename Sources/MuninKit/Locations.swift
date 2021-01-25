//
//  Locations.swift
//  MuninPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 18/03/2018.
//

import Foundation
import Logging

public struct Locations: Codable {
  var locations: [Location]

  init(gallery: Gallery) {
    locations = locationsFromAlbum(album: gallery.input)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(Array(locations).sorted(), forKey: .locations)
  }

  public func write(ctx: Context) {
    log.info("Writing locations")
    let fileURL = URL(
      fileURLWithPath: joinPath(ctx.config.outputPath, ctx.config.name, "locations.json"))

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    if let encodedData = try? encoder.encode(self) {
      do {
        log.trace("Writing locations to json to \(fileURL.path)")
        try encodedData.write(to: URL(fileURLWithPath: fileURL.path))
      } catch {
        log.error("Could not write locations json to \(fileURL.path) with error: \n\(error)")
      }
    }
  }
}

struct Location: Codable, Comparable {
  var url: String
  var gps: GPS
  var scaledPhotos: [ScaledPhoto]
}

extension Location {
  static func < (lhs: Location, rhs: Location) -> Bool {
    return lhs.url < rhs.url
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
