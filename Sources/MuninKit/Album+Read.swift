import Foundation
import SystemPackage

/// Recursively read an input directory into an `Album` tree.
///
/// Photos within a single directory are read in parallel via
/// `withThrowingTaskGroup`, bounded by an `AsyncSemaphore` sized from
/// `ctx.config.concurrency` so we never have more than N VIPS/EXIF reads in
/// flight at once. Sub-album directories are traversed sequentially (they in
/// turn parallelise their own photo reads).
///
/// `priorPhotos`, when supplied, is a lookup of previously-written photos
/// keyed by output URL (e.g. `/out/root/Misc/portrait_mm.json`). Each
/// per-photo read consults the map so unchanged files skip the full
/// EXIF/VIPS/hash cost — see `Photo+Read.swift` for the decision tree.
func readStateFromInputDirectory(
  ctx: Context,
  atPath: String,
  outPath: String,
  name: String,
  parents: [Parent],
  sem: AsyncSemaphore? = nil,
  priorPhotos: [String: Photo] = [:]
) async throws -> Album {
  let sem = sem ?? AsyncSemaphore(value: max(ctx.config.concurrency, 1))
  ctx.log.trace("Creating album from path: \(joinPath(atPath))")

  let albumOutPath = joinPath(outPath, urlifyName(name))
  var album = Album(name: name, path: albumOutPath, parents: parents)
  let parent = Parent(name: album.name, url: album.url)
  var newParents = parents
  newParents.append(parent)
  let capturedParents = newParents

  // Sub-albums (depth-first). They nest under this album's *own* output
  // directory — the urlified one. Handing them the raw `name` instead put
  // every sub-album of an album whose name contains a space into a
  // parallel directory the parent never claimed, so the parent's `albums`
  // entry pointed at a path outside its own tree and `clean` deleted the
  // lot as unreferenced: every photo below such an album was written and
  // then erased in the same run.
  let directories = directoryNames(under: FilePath(joinPath(atPath)))
  for directory in directories {
    let childAlbum = try await readStateFromInputDirectory(
      ctx: ctx,
      atPath: joinPath(atPath, directory),
      outPath: albumOutPath,
      name: directory,
      parents: capturedParents,
      sem: sem,
      priorPhotos: priorPhotos
    )
    album.albums.insert(childAlbum)
    album.keywords = album.keywords.union(childAlbum.keywords)
    album.people = album.people.union(childAlbum.people)
  }

  // Parallel photo reads with bounded concurrency.
  let extensionSet = Set(ctx.config.fileExtensions)
  let files = fileOrSymlinkNames(under: FilePath(joinPath(atPath))).filter {
    extensionSet.contains(fileExtension(atPath: joinPath(atPath, $0)) ?? "")
  }

  let readPhotos: [Photo] = try await withThrowingTaskGroup(of: Photo?.self) { group in
    for file in files {
      let filePath = joinPath(atPath, file)
      let fileNameWithoutExt = fileNameWithoutExtension(atPath: filePath)
      guard let fileExt = fileExtension(atPath: filePath) else {
        ctx.log.warning("File found, but it was not a photo, path: \(filePath)")
        continue
      }

      // Precompute the Photo's URL the same way readPhotoFromPath does,
      // then consult priorPhotos. Keyed by URL (not by source path) so
      // moving the source tree without changing the output root still
      // hits the cache.
      let photoUrl = "\(joinPath(albumOutPath, fileNameWithoutExt)).json"
      let prior = priorPhotos[photoUrl]

      await sem.wait()
      group.addTask {
        let photo = readPhotoFromPath(
          atPath: filePath,
          outPath: albumOutPath,
          name: fileNameWithoutExt,
          fileExtension: fileExt,
          parents: capturedParents,
          ctx: ctx,
          prior: prior
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

  // Sort by capture time with name as tie-breaker, then wire up
  // next/previous navigation. Using `Photo.<` (instead of a bare
  // `dateTime` comparator) keeps the ordering deterministic across
  // runs even when directory-listing order drifts.
  var photos = readPhotos.sorted(by: <)
  let photoCount = photos.count
  for index in photos.indices {
    let previousIndex = index == 0 ? photoCount - 1 : index - 1
    let nextIndex = index == photoCount - 1 ? 0 : index + 1
    photos[index].previous = photos[previousIndex].url.string
    photos[index].next = photos[nextIndex].url.string
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
///
/// Photos whose on-disk outputs (JSON, symlinked original, or any scaled
/// JPEG) are no longer present are pruned from the returned tree so the
/// incremental diff in `Gallery.load` sees them as "not present in output"
/// and regenerates the missing files. Without this, `sourceHash` equality
/// hides missing-output photos and the two-pass write in `Gallery.build`
/// never restores them.
func readStateFromOutputDirectory(indexFileAtPath: String) -> Album? {
  guard let album = readAndDecodeJsonFile(Album.self, atPath: indexFileAtPath) else {
    return nil
  }
  return pruneIncompleteOutputPhotos(album)
}

/// Drop any `Photo` whose `expectedFiles` are not all present on disk.
/// Dangling symlinks at `originalImageURL` still count as present — the
/// symlink itself exists, and `Photo+Read` owns detection of source moves.
private func pruneIncompleteOutputPhotos(_ album: Album) -> Album {
  var out = album
  out.photos = Set(
    album.photos.filter { photo in
      photo.expectedFiles.allSatisfy { url in
        isFileOrSymlink(at: FilePath(url.path))
      }
    })
  out.albums = Set(album.albums.map(pruneIncompleteOutputPhotos))
  return out
}
