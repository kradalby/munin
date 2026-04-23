import Foundation

extension Album {
  // MARK: - Expected / missing / unreferenced files

  /// All sub-album folders expected to exist under this album on disk.
  var expectedFolders: [URL] {
    albums.map { URL(fileURLWithPath: $0.path) }
  }

  /// All files expected to exist directly in this album's folder: the album
  /// JSON, every photo's expected files, and (for the root album only) the
  /// shared `stats.json` / `locations.json`.
  ///
  /// Does **not** recurse into sub-albums — those are their own folders and
  /// own expected-files lists.
  var expectedFiles: [URL] {
    let jsonURL = URL(fileURLWithPath: url)

    // TODO(FUTURES.md): replace with explicit expectedFiles on Keywords,
    // Locations, and Stats once those become first-class types.
    let rootFiles: [URL] =
      parents.isEmpty
      ? [
        URL(fileURLWithPath: joinPath(path, "stats.json")),
        URL(fileURLWithPath: joinPath(path, "locations.json")),
      ]
      : []

    return [jsonURL] + photos.flatMap { $0.expectedFiles } + rootFiles
  }

  /// Folders that exist on disk under `path` but are not represented by any
  /// sub-album.
  var unreferencedFolders: [URL] {
    let fileManager = FileManager()
    let actualFolders = fileManager.directoriesOfDirectory(atPath: path).map {
      URL(fileURLWithPath: joinPath(path, $0))
    }
    return actualFolders.filter { !expectedFolders.contains($0) }
  }

  /// Files that exist on disk under `path` but are not part of this album's
  /// expected output.
  var unreferencedFiles: [URL] {
    let fileManager = FileManager()
    let actualFiles = fileManager.filesOfDirectory(atPath: path).map {
      URL(fileURLWithPath: joinPath(path, $0))
    }
    return actualFiles.filter { !expectedFiles.contains($0) }
  }

  /// Files this album declares as expected but that are missing from disk.
  var missingFiles: [URL] {
    let fileManager = FileManager()
    let actualFiles = fileManager.filesOfDirectory(atPath: path).map {
      URL(fileURLWithPath: joinPath(path, $0))
    }
    return expectedFiles.filter { !actualFiles.contains($0) }
  }

  // MARK: - Diff helpers

  /// Shallow copy of this album with an empty photos/albums tree. Used by
  /// the diff algorithm to express "the shape of this album, ignoring its
  /// contents".
  func copyWithoutChildren() -> Album {
    var newAlbum = Album(name: name, path: path, parents: parents)
    newAlbum.url = url
    newAlbum.photos = []
    newAlbum.albums = []
    newAlbum.keywords = keywords
    newAlbum.people = people
    return newAlbum
  }

  /// Photos that `other` has but `self` does not.
  func changedPhotos(_ other: Album) -> Set<Photo> {
    return other.photos.subtracting(photos)
  }

  /// Sub-albums that `other` has but `self` does not.
  func changedAlbums(_ other: Album) -> Set<Album> {
    return other.albums.subtracting(albums)
  }

  /// The first landscape-orientation photo found by depth-first traversal,
  /// used to supply a cover image for an album.
  func landscapeCoverPhoto() -> Photo? {
    for photo in photos.sorted() where photo.orientation == Orientation.landscape {
      return photo
    }

    for album in albums.sorted() {
      if let photo = album.landscapeCoverPhoto() {
        return photo
      }
    }

    return nil
  }

  // MARK: - Counts / traversal

  /// Number of photos in this album (optionally including all nested
  /// sub-albums).
  func numberOfPhotos(travers: Bool) -> Int {
    if travers {
      return albums.map { $0.numberOfPhotos(travers: travers) }.reduce(0, +) + photos.count
    }
    return photos.count
  }

  /// Number of sub-albums (optionally recursive).
  func numberOfAlbums(travers: Bool) -> Int {
    if travers {
      return albums.map { $0.numberOfAlbums(travers: travers) }.reduce(0, +) + albums.count
    }
    return albums.count
  }

  /// Every photo in this album and every nested sub-album, deduplicated.
  func flattenPhotos() -> Set<Photo> {
    return photos.union(
      albums.map { $0.flattenPhotos() }.reduce(Set()) { x, y in
        x.union(y)
      })
  }

  /// Whether this album (and optionally every nested sub-album) has zero
  /// photos.
  func isEmpty(travers: Bool) -> Bool {
    for album in albums {
      if !album.isEmpty(travers: travers) {
        return false
      }
    }
    return photos.isEmpty
  }
}
