import Foundation

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
      let encoder = MuninJSON.encoder()
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
          await ctx.state.incrementPhotosWritten()
          await sem.signal()
        }
      }
      try await group.waitForAll()
    }
  }

  /// Remove this album and every one of its photos and sub-albums from disk.
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
}
