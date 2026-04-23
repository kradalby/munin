import Foundation

extension Album {
  /// Remove files and folders on disk that no longer belong to this album.
  public func clean(ctx: Context) {
    let fileManager = FileManager()
    let unrefFiles = unreferencedFiles
    let unrefFolders = unreferencedFolders

    ctx.log.info("Cleaning album \(name) of unreferenced files: \(unrefFiles)")
    ctx.log.info("Cleaning album \(name) of unreferenced folders: \(unrefFolders)")

    for album in albums {
      album.clean(ctx: ctx)
    }

    for file in unrefFiles + unrefFolders {
      do {
        try fileManager.removeItem(at: file)
      } catch {
        ctx.log.error("Could not remove album \(name) at path \(path): \(error)")
      }
    }
  }
}
