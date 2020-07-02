//
//  Locations.swift
//  MuninPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 18/03/2018.
//

import Foundation

public struct Locations: Codable {
  var locations: [Location]

  init(gallery: Gallery) {
    locations = locationsFromAlbum(album: gallery.input)
  }

  public func write(config: GalleryConfiguration) {
    log.info("Writing locations")
    let fileURL = URL(
      fileURLWithPath: joinPath(paths: config.outputPath, config.name, "locations.json"))

    let encoder = JSONEncoder()

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

struct Location: Codable {
  var url: String
  var gps: GPS
  var scaledPhotos: [ScaledPhoto]
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
