import Foundation
import SystemPackage

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
    // A directory we can't create means every photo and sub-album
    // underneath has nowhere to write to. This used to log-and-return,
    // silently dropping the whole subtree; now it throws so the build
    // aborts rather than producing a hollow output.
    do {
      try POSIX.createDirectory(path)
    } catch {
      throw MuninError.directoryCreationFailed(
        path: path.string, underlying: String(describing: error))
    }

    ctx.log.trace("Writing metadata for album \(name)")
    if writeJson {
      let encoder = MuninJSON.encoder()
      let encodedData: Data
      do {
        encodedData = try encoder.encode(self)
      } catch {
        throw MuninError.metadataWriteFailed(
          path: url.string, underlying: String(describing: error))
      }
      ctx.log.trace("Writing album metadata \(name) to \(url)")
      try FileIO.writeAtomic(encodedData, to: url)
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
          do {
            try photo.write(ctx: ctx, writeJson: writeJson, writeImage: writeImage)
          } catch let error as MuninError {
            ctx.log.error("Photo \(photo.name) write failed: \(error)")
            await ctx.state.recordFailure(
              PhotoWriteFailure(photo: photo.name, path: photo.url, error: error))
          } catch {
            // Non-MuninError thrown out of `Photo.write` shouldn't exist
            // given the typed throws surface, but if one slips through
            // wrap it so the CLI summary still accounts for it.
            ctx.log.error("Photo \(photo.name) write failed: \(error)")
            await ctx.state.recordFailure(
              PhotoWriteFailure(
                photo: photo.name,
                path: photo.url,
                error: .imageOperationFailed(
                  path: photo.url.string,
                  operation: "write",
                  underlying: String(describing: error))))
          }
          await ctx.state.incrementPhotosWritten()
          await sem.signal()
        }
      }
      try await group.waitForAll()
    }
  }

  /// Remove this album and every one of its photos and sub-albums from disk.
  public func destroy(ctx: Context) {
    ctx.log.info("Inside: \(name)")
    ctx.log.info("Destroying: \(photos)")
    for photo in photos {
      photo.destroy(ctx: ctx)
    }

    for album in albums {
      album.destroy(ctx: ctx)
    }

    do {
      try POSIX.unlink(url)
    } catch {
      ctx.log.error("Could not remove album json \(name) at path \(url)")
    }

    do {
      try POSIX.rmdir(path)
    } catch {
      ctx.log.error("Could not remove album \(name) at path \(path)")
    }
  }
}
