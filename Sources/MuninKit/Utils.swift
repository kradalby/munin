//
//  Utils.swift
//  galPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Foundation
import Logging

// ANSI escapes for the `--diff` pretty-print markers. `prettyPrintAlbum`
// writes through `print(...)` which already bypasses any colour-aware
// terminal abstraction, so keeping two local constants is simpler than
// pulling in a colour-helper dependency.
private let ansiGreen = "\u{001B}[32m"
private let ansiRed = "\u{001B}[31m"
private let ansiReset = "\u{001B}[0m"

func readAndDecodeJsonFile<T>(_ type: T.Type, atPath: String) -> T?
where T: Decodable {
  let fileManager = FileManager()
  var isDirectory: ObjCBool = ObjCBool(false)
  let exists = fileManager.fileExists(atPath: atPath, isDirectory: &isDirectory)

  if exists, !isDirectory.boolValue {
    if let indexFile = try? Data(contentsOf: URL(fileURLWithPath: atPath)) {
      let decoder = MuninJSON.decoder()

      if let decodedData = try? decoder.decode(type, from: indexFile) {
        return decodedData
      } else {
        // TODO: Use logger
        print("Error: Could not decode \(atPath)")
      }
    } else {
      // TODO: Use logger
      print("Error: Could not read \(atPath)")
    }
  } else {
    // TODO: Use logger
    print("Error: File \(atPath) does not exist")
  }
  return nil
}

func createOrReplaceSymlink(ctx: Context, source: String, destination: String) throws {
  let fileManager = FileManager()

  var isDirectory: ObjCBool = ObjCBool(false)
  let exists = fileManager.fileExists(atPath: destination, isDirectory: &isDirectory)
  if exists || isDirectory.boolValue {
    ctx.log.trace("Symlink exists, removing \(destination)")
    try fileManager.removeItem(atPath: destination)
  }

  try fileManager.createSymbolicLink(atPath: destination, withDestinationPath: source)
}

func joinPath(_ paths: String...) -> String {
  return Paths.join(paths)
}

func joinPath(_ paths: [String]) -> String {
  return Paths.join(paths)
}

func fileExtension(atPath: String) -> String? {
  // Historical behaviour: a file with no extension returned `""`, not nil,
  // because `URL.pathExtension` does. Preserve that for callers that rely on
  // the non-nil result (e.g. the `guard let fileExt` in Album+Read.swift
  // currently treats `""` as a missing extension anyway).
  return Paths.extension(atPath) ?? ""
}

func fileNameWithoutExtension(atPath: String) -> String {
  return Paths.stem(atPath)
}

func pathWithoutFileName(atPath: String) -> String {
  let url = URL(fileURLWithPath: atPath)
  return url.deletingLastPathComponent().relativeString
}

extension Date {
  var millisecondsSince1970: Int64 {
    return Int64((timeIntervalSince1970 * 1000.0).rounded())
  }

  init(milliseconds: Int64) {
    self = Date(timeIntervalSince1970: TimeInterval(milliseconds / 1000))
  }
}

// When the modified date is encoded to json, the millisecond accuracy is lost.
// Therefore we remove it before so we can do a proper equal of the picture to
// seconds accuracy.
func fileModificationDate(url: URL) -> Date? {
  do {
    let attr = try FileManager.default.attributesOfItem(atPath: url.path)
    if let date = attr[FileAttributeKey.modificationDate] as? Date {
      let rounded = date.millisecondsSince1970 - (date.millisecondsSince1970 % 1000)
      let roundedDate = Date(milliseconds: rounded)
      return roundedDate
    }
    return nil
  } catch {
    return nil
  }
}

/// Byte count of the file at `url`, or `nil` if the size cannot be read.
/// Used (together with `fileModificationDate`) as a cache key on `Photo`
/// so an unchanged source file can skip both hashing and EXIF/VIPS work.
func fileSizeInBytes(url: URL) -> Int? {
  do {
    let attr = try FileManager.default.attributesOfItem(atPath: url.path)
    if let size = attr[FileAttributeKey.size] as? NSNumber {
      return size.intValue
    }
    return nil
  } catch {
    return nil
  }
}

func prettyPrintAlbum(_ album: Album, marker: String = "") {
  let indentCharacter = "  "
  func prettyPrintAlbumRecursive(_ album: Album, indent: Int) {
    let indentString = String(repeating: indentCharacter, count: indent)
    let indentChildString = String(repeating: indentCharacter, count: indent + 1)

    // TODO: Determine of this should be log or print
    print("\(indentString) \(marker) Album: \(album.name)")
    for photo in album.photos {
      // TODO: Determine of this should be log or print
      print("\(indentChildString) \(marker) Photo: \(photo.name)")
    }
    for childAlbum in album.albums {
      prettyPrintAlbumRecursive(childAlbum, indent: indent + 1)
    }
  }
  prettyPrintAlbumRecursive(album, indent: 0)
}

func prettyPrintAdded(_ album: Album) {
  prettyPrintAlbum(album, marker: "\(ansiGreen)[+]\(ansiReset)")
}

func prettyPrintRemoved(_ album: Album) {
  prettyPrintAlbumCompact(album, marker: "\(ansiRed)[-]\(ansiReset)")
}

func prettyPrintAlbumCompact(_ album: Album, marker: String) {
  if !album.photos.isEmpty {
    print("Album: \(album.url)")
  }
  for photo in album.photos {
    print("\(marker): \(photo.url)")
  }

  for childAlbum in album.albums {
    prettyPrintAlbumCompact(childAlbum, marker: marker)
  }
}

func urlifyName(_ name: String) -> String {
  return Paths.urlify(name)
}

extension Collection {
  /// Returns the element at the specified index iff it is within bounds, otherwise nil.
  subscript(safe index: Index) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
}

// func prettyPrintAdded(added: Album?) -> String {
//   var str = ""
//   if let a = added {
//     let astr = """

//       Added:
//       \(prettyPrintAdded(a))

//       """

//     str = str + astr
//   }
//   return str
// }

func computeChangedPhotos(input: Album, output: Album) -> Album? {
  if input == output {
    return nil
  }

  var changed = input.copyWithoutChildren()
  changed.photos = output.changedPhotos(input)

  // print("----------------------------")
  // output.photos.forEach {
  //   print("output: \($0.name)")
  // }
  // input.photos.forEach {
  //   print("input: \($0.name)")
  // }
  // changed.photos.forEach {
  //   print("changed: \($0.name)")
  // }

  changed.albums = Set(
    output.changedAlbums(input).compactMap { changedAlbum in
      if let outputAlbum = findAlbumByName(name: changedAlbum.name, album: output) {
        if let computedChange = computeChangedPhotos(input: changedAlbum, output: outputAlbum) {
          return computedChange
        }
      }
      // If there is no output album present, then it is a new album.
      return changedAlbum
    })

  return changed
}

// Recursively search through a list of albums and their children to find
// an album by name.
func findAlbumByName(name: String, albums: [Album]) -> Album? {
  for album in albums {
    if let found = findAlbumByName(name: name, album: album) {
      return found
    }
  }
  return nil
}

func findAlbumByName(name: String, album: Album) -> Album? {
  if album.name == name {
    return album
  }
  for alb in album.albums {
    if let found = findAlbumByName(name: name, album: alb) {
      return found
    }
  }
  return nil
}

func isAlbumInListByName(album: Album, albums: [Album]) -> Bool {
  for item in albums where album.name == item.name {
    return true
  }
  return false
}

func randomString(length: Int) -> String {
  let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  return String((0..<length).map { _ in letters.randomElement()! })
}

func stringToLogLevel(_ level: String) -> Logger.Level {
  switch level {
  case "trace":
    return .trace
  case "debug":
    return .debug
  case "info":
    return .info
  case "notice":
    return .notice
  case "warning":
    return .warning
  case "error":
    return .error
  case "critical":
    return .critical
  default:
    return .info
  }
}
