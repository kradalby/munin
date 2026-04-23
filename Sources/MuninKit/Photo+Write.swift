import Foundation
import VIPS

extension Photo {
  /// Write this photo to disk: generate scaled thumbnails, symlink the
  /// original, and serialize the metadata JSON.
  func write(ctx: Context, writeJson: Bool, writeImage: Bool) {
    ctx.log.trace("Photo: \(name) has \(writeImage)")
    // Only write images and symlink if the user wants to
    if writeImage {
      ctx.log.trace("Writing image \(name)")
      let fileURL = URL(fileURLWithPath: originalImagePath)
      do {
        let image = try VIPSImage(fromFilePath: fileURL.path)

        for scaledPhoto in scaledPhotos {
          do {
            ctx.log.trace(
              "Writing image \(name) at \(scaledPhoto.maxResolution)px to \(scaledPhoto.url)")
            try image.thumbnailImage(width: scaledPhoto.maxResolution, crop: .none)
              .writeToFile(
                URL(fileURLWithPath: scaledPhoto.url).path,
                quality: Int(ctx.config.jpegCompression * 100))
          } catch {
            ctx.log.error(
              "Could not write image \(name) to \(scaledPhoto.url): \(error)")
          }
        }

      } catch {
        ctx.log.error("Could not open image at \(fileURL.path): \(error)")
      }

      let relativeOriginialPath = Array(repeating: "..", count: depth) + [originalImagePath]
      ctx.log.trace("Symlinking original image \(name) to \(originalImageURL)")
      do {
        try createOrReplaceSymlink(
          ctx: ctx,
          source: joinPath(relativeOriginialPath),
          destination: originalImageURL
        )
      } catch {
        ctx.log.error(
          "Could not symlink image \(name) to \(originalImageURL) with error: \n\(error)")
      }
    }

    if writeJson {
      ctx.log.trace("Writing metadata for image \(name)")
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601

      if let encodedData = try? encoder.encode(self) {
        do {
          ctx.log.trace("Writing image metadata \(name) to \(url)")
          try encodedData.write(to: URL(fileURLWithPath: url))
        } catch {
          ctx.log.error("Could not write image \(name) to \(url) with error: \n\(error)")
        }
      }
    }
  }

  /// Remove this photo's files from disk: JSON, symlinked original, and every
  /// scaled resolution.
  func destroy(ctx: Context) {
    let fileManager = FileManager()
    ctx.log.trace("Removing image \(name)")
    let jsonURL = URL(fileURLWithPath: url)
    let symlinkedImageURL = URL(fileURLWithPath: originalImageURL)
    do {
      try fileManager.removeItem(at: jsonURL)
    } catch {
      ctx.log.error("Could not remove image json \(name) at path \(url)")
    }

    do {
      try fileManager.removeItem(at: symlinkedImageURL)
    } catch {
      ctx.log.error("Could not remove image json \(name) at path \(originalImageURL)")
    }

    for scaledPhoto in scaledPhotos {
      let fileURL = URL(fileURLWithPath: scaledPhoto.url)
      do {
        try fileManager.removeItem(at: fileURL)
      } catch {
        ctx.log.error("Could not remove image \(name) at path \(scaledPhoto.url)")
      }
    }
  }
}
