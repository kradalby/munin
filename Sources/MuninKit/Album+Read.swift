import Foundation

/// Recursively read an input directory into an `Album` tree.
///
/// Photos within a single directory are read in parallel via
/// `withThrowingTaskGroup`, bounded by an `AsyncSemaphore` sized from
/// `ctx.config.concurrency` so we never have more than N VIPS/EXIF reads in
/// flight at once. Sub-album directories are traversed sequentially (they in
/// turn parallelise their own photo reads).
func readStateFromInputDirectory(
  ctx: Context,
  atPath: String,
  outPath: String,
  name: String,
  parents: [Parent],
  sem: AsyncSemaphore? = nil
) async throws -> Album {
  let sem = sem ?? AsyncSemaphore(value: max(ctx.config.concurrency, 1))
  ctx.log.trace("Creating album from path: \(joinPath(atPath))")

  var album = Album(name: name, path: joinPath(outPath, urlifyName(name)), parents: parents)
  let parent = Parent(name: album.name, url: album.url)
  var newParents = parents
  newParents.append(parent)
  let capturedParents = newParents

  // Sub-albums (depth-first).
  let directories = FileManager.default.directoriesOfDirectory(atPath: joinPath(atPath))
  for directory in directories {
    let childAlbum = try await readStateFromInputDirectory(
      ctx: ctx,
      atPath: joinPath(atPath, directory),
      outPath: joinPath(outPath, name),
      name: directory,
      parents: capturedParents,
      sem: sem
    )
    album.albums.insert(childAlbum)
    album.keywords = album.keywords.union(childAlbum.keywords)
    album.people = album.people.union(childAlbum.people)
  }

  // Parallel photo reads with bounded concurrency.
  let files = FileManager.default.filesOfDirectoryByExtensions(
    atPath: joinPath(atPath), extensions: ctx.config.fileExtensions
  )
  let albumOutPath = joinPath(outPath, urlifyName(name))

  let readPhotos: [Photo] = try await withThrowingTaskGroup(of: Photo?.self) { group in
    for file in files {
      let filePath = joinPath(atPath, file)
      let fileNameWithoutExt = fileNameWithoutExtension(atPath: filePath)
      guard let fileExt = fileExtension(atPath: filePath) else {
        ctx.log.warning("File found, but it was not a photo, path: \(filePath)")
        continue
      }

      await sem.wait()
      group.addTask {
        let photo = readPhotoFromPath(
          atPath: filePath,
          outPath: albumOutPath,
          name: fileNameWithoutExt,
          fileExtension: fileExt,
          parents: capturedParents,
          ctx: ctx
        )
        await ctx.state.updatePhotosToWrite(name: filePath)
        await sem.signal()

        guard let photo else { return nil }
        if !photo.shouldInclude {
          ctx.log.debug(
            "Photo \(photo.name) included \(PhotoConstants.excludeKeyword) keyword, ignoring...")
          return nil
        }
        return photo
      }
    }

    var collected: [Photo] = []
    for try await result in group {
      if let photo = result {
        collected.append(photo)
      }
    }
    return collected
  }

  // Sort by capture time, then wire up next/previous navigation.
  var photos = readPhotos.sorted {
    ($0.dateTime ?? .distantPast) < ($1.dateTime ?? .distantPast)
  }
  let photoCount = photos.count
  for index in photos.indices {
    let previousIndex = index == 0 ? photoCount - 1 : index - 1
    let nextIndex = index == photoCount - 1 ? 0 : index + 1
    photos[index].previous = photos[previousIndex].url
    photos[index].next = photos[nextIndex].url
  }

  for photo in photos {
    album.photos.insert(photo)
    album.keywords = album.keywords.union(photo.keywords)
    album.people = album.people.union(photo.people)
  }

  return album
}

/// Read a previously-generated output album tree from the `index.json`
/// written by `Album.write`. Returns `nil` if the file is missing — which
/// the Gallery treats as "first run, no existing output".
func readStateFromOutputDirectory(indexFileAtPath: String) -> Album? {
  return readAndDecodeJsonFile(Album.self, atPath: indexFileAtPath)
}
