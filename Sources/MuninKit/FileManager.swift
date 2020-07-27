import Foundation

extension FileManager {
  func filesOfDirectory(atPath: String) -> [String] {
    if let contents = try? self.contentsOfDirectory(atPath: atPath) {
      return contents.filter { self.isFile(atPath: joinPath(paths: atPath, $0)) }
    }
    return []
  }

  func filesOfDirectoryByExtensions(atPath: String, extensions: [String]) -> [String] {
    self.filesOfDirectory(atPath: atPath).filter {
      extensions.contains(fileExtension(atPath: joinPath(paths: atPath, $0)) ?? "")
    }

  }

  func directoriesOfDirectory(atPath: String) -> [String] {
    if let contents = try? self.contentsOfDirectory(atPath: atPath) {
      return contents.filter { self.isDirectory(atPath: joinPath(paths: atPath, $0)) }
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
}
