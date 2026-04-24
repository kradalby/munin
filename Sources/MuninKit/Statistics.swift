//
//  Statistics.swift
//  GalPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 14/01/2018.
//

import Foundation
import Logging
import SystemPackage

public struct Statistics: Codable, Sendable {
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

  public func write(ctx: Context) throws {
    ctx.log.info("Writing stats")
    let path = FilePath(joinPath(ctx.config.outputPath, ctx.config.name, "stats.json"))

    let encoder = MuninJSON.encoder()
    let encodedData: Data
    do {
      encodedData = try encoder.encode(self)
    } catch {
      throw MuninError.metadataWriteFailed(
        path: path.string, underlying: String(describing: error))
    }

    ctx.log.trace("Writing statistics to json to \(path)")
    try FileIO.writeAtomic(encodedData, to: path)
  }
}
