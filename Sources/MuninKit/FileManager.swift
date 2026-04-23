import Foundation

extension FileManager {
  /// All file-like entries (regular files and symlinks) directly under
  /// `atPath`.
  ///
  /// Symlinks are included whether or not their target currently exists.
  /// The clean pipeline depends on this so that a photo whose source was
  /// removed between builds — leaving behind a dangling `_original.*`
  /// symlink in the output tree — still gets cleaned as an unreferenced
  /// entry.
  func filesOfDirectory(atPath: String) -> [String] {
    if let contents = try? self.contentsOfDirectory(atPath: atPath) {
      return contents.filter { self.isFileOrSymlink(atPath: joinPath(atPath, $0)) }
    }
    return []
  }

  func filesOfDirectoryByExtensions(atPath: String, extensions: [String]) -> [String] {
    self.filesOfDirectory(atPath: atPath).filter {
      extensions.contains(fileExtension(atPath: joinPath(atPath, $0)) ?? "")
    }

  }

  func directoriesOfDirectory(atPath: String) -> [String] {
    if let contents = try? self.contentsOfDirectory(atPath: atPath) {
      return contents.filter { self.isDirectory(atPath: joinPath(atPath, $0)) }
    }
    return []
  }

  func isFile(atPath: String) -> Bool {
    var isDirectory: ObjCBool = ObjCBool(false)
    let exists = self.fileExists(
      atPath: atPath,
      isDirectory: &isDirectory
    )
    return exists && !isDirectory.boolValue
  }

  func isDirectory(atPath: String) -> Bool {
    var isDirectory: ObjCBool = ObjCBool(false)
    let exists = self.fileExists(
      atPath: atPath,
      isDirectory: &isDirectory
    )
    return exists && isDirectory.boolValue
  }

  /// Whether `atPath` is a regular file OR a symlink (including symlinks
  /// whose target has disappeared). `fileExists(atPath:)` follows
  /// symlinks, so a dangling symlink reports as non-existent — this
  /// helper inspects the link itself via `attributesOfItem`, which does
  /// not follow symlinks.
  func isFileOrSymlink(atPath: String) -> Bool {
    guard let attrs = try? self.attributesOfItem(atPath: atPath) else { return false }
    let type = attrs[.type] as? FileAttributeType
    return type == .typeRegular || type == .typeSymbolicLink
  }
}
