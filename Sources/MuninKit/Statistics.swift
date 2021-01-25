//
//  Statistics.swift
//  GalPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 14/01/2018.
//

import Foundation
import Logging

public struct Statistics: Codable {
  var originalPhotos: Int
  var writtenPhotos: Int
  var albums: Int
  var keywords: Int
  var people: Int

  init(ctx: Context, gallery: Gallery) {
    originalPhotos = gallery.input.numberOfPhotos(travers: true)
    albums = gallery.input.numberOfAlbums(travers: true)

    writtenPhotos = originalPhotos * ctx.config.resolutions.count

    keywords = gallery.input.keywords.count
    people = gallery.input.people.count
  }

  public func toString() -> String {
    return """
      Gallery contains:
      \t\(originalPhotos) original photos
      \t\(albums) albums
      \t\(keywords) keywords
      \t\(people) people

      \t\(writtenPhotos) photos has been encoded
      """
  }

  public func write(ctx: Context) {
    log.info("Writing stats")
    let fileURL = URL(
      fileURLWithPath: joinPath(ctx.config.outputPath, ctx.config.name, "stats.json"))

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601

    if let encodedData = try? encoder.encode(self) {
      do {
        log.trace("Writing statistics to json to \(fileURL.path)")
        try encodedData.write(to: URL(fileURLWithPath: fileURL.path))
      } catch {
        log.error("Could not write statistics json to \(fileURL.path) with error: \n\(error)")
      }
    }
  }
}
