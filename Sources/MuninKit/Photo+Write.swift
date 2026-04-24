import Foundation
import SystemPackage

extension Photo {
  /// Write this photo to disk: generate scaled thumbnails, symlink the
  /// original, and serialize the metadata JSON.
  ///
  /// Failure model:
  /// - A VIPS open error is fatal for this photo (no scaled images
  ///   possible) and is thrown as `MuninError.imageOperationFailed`.
  /// - An individual scaled-size write failure is partial — other sizes
  ///   may still succeed — and is logged without aborting the photo.
  /// - Symlink and metadata-JSON failures are fatal for this photo
  ///   (the on-disk output would be incomplete) and are re-thrown.
  ///
  /// The caller (`Album.write`) wraps this call and records any thrown
  /// `MuninError` as a `PhotoWriteFailure` on the build state so the run
  /// can continue and report every failed photo at the end.
  func write(ctx: Context, writeJson: Bool, writeImage: Bool) throws {
    ctx.log.trace("Photo: \(name) has \(writeImage)")
    if writeImage {
      try writeImageOutputs(ctx: ctx)
    }

    if writeJson {
      try writeMetadata(ctx: ctx)
    }
  }

  private func writeImageOutputs(ctx: Context) throws {
    ctx.log.trace("Writing image \(name)")

    let targets = scaledPhotos.map {
      ScaleTarget(width: $0.maxResolution, path: $0.url)
    }
    let result = try Imaging.scaleJPEG(
      source: originalImagePath,
      destinations: targets,
      quality: Int(ctx.config.jpegCompression * 100))

    // Per-size write failures are partial (other sizes may still have
    // succeeded). Surfacing every bad thumbnail as a top-level
    // failure would drown the summary, so keep today's log-and-continue
    // shape — just pulled out of the scaling loop.
    for failure in result.failures {
      ctx.log.error(
        "Could not write image \(name) to \(failure.destination): \(failure.error)")
    }

    let relativeOriginialPath = Array(repeating: "..", count: depth) + [originalImagePath.string]
    ctx.log.trace("Symlinking original image \(name) to \(originalImageURL)")
    try createOrReplaceSymlink(
      ctx: ctx,
      source: FilePath(joinPath(relativeOriginialPath)),
      destination: originalImageURL
    )
  }

  private func writeMetadata(ctx: Context) throws {
    ctx.log.trace("Writing metadata for image \(name)")
    let encoder = MuninJSON.encoder()

    let encodedData: Data
    do {
      encodedData = try encoder.encode(self)
    } catch {
      throw MuninError.metadataWriteFailed(
        path: url.string, underlying: String(describing: error))
    }

    ctx.log.trace("Writing image metadata \(name) to \(url)")
    try FileIO.writeAtomic(encodedData, to: url)
  }

  /// Remove this photo's files from disk: JSON, symlinked original, and every
  /// scaled resolution.
  func destroy(ctx: Context) {
    ctx.log.trace("Removing image \(name)")
    do {
      try POSIX.unlink(url)
    } catch {
      ctx.log.error("Could not remove image json \(name) at path \(url)")
    }

    do {
      try POSIX.unlink(originalImageURL)
    } catch {
      ctx.log.error("Could not remove image json \(name) at path \(originalImageURL)")
    }

    for scaledPhoto in scaledPhotos {
      do {
        try POSIX.unlink(scaledPhoto.url)
      } catch {
        ctx.log.error("Could not remove image \(name) at path \(scaledPhoto.url)")
      }
    }
  }
}
