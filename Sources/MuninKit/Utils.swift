//
//  Utils.swift
//  galPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Foundation
import Logging
import SystemPackage

// ANSI escapes for the `--diff` pretty-print markers. `prettyPrintAlbum`
// writes through `print(...)` which already bypasses any colour-aware
// terminal abstraction, so keeping two local constants is simpler than
// pulling in a colour-helper dependency.
private let ansiGreen = "\u{001B}[32m"
private let ansiRed = "\u{001B}[31m"
private let ansiReset = "\u{001B}[0m"

func readAndDecodeJsonFile<T>(_ type: T.Type, atPath path: FilePath) -> T?
where T: Decodable {
  // Existence + not-a-directory check via lstat; mirrors the old
  // fileExists(isDirectory:) call pattern without pulling in FileManager.
  guard let info = try? POSIX.lstat(path) else {
    print("Error: File \(path) does not exist")
    return nil
  }
  if info.isDirectory {
    print("Error: File \(path) does not exist")
    return nil
  }

  let data: Data
  do {
    data = try FileIO.read(path)
  } catch {
    print("Error: Could not read \(path): \(error)")
    return nil
  }

  let decoder = MuninJSON.decoder()
  do {
    return try decoder.decode(type, from: data)
  } catch {
    print("Error: Could not decode \(path): \(error)")
    return nil
  }
}

/// String-path convenience overload so callers that still carry a plain
/// `String` (e.g. configuration file paths) don't need to wrap at every
/// call site.
func readAndDecodeJsonFile<T>(_ type: T.Type, atPath: String) -> T?
where T: Decodable {
  readAndDecodeJsonFile(type, atPath: FilePath(atPath))
}

func createOrReplaceSymlink(ctx: Context, source: FilePath, destination: FilePath) throws {
  // POSIX.unlink treats ENOENT as success, so no need to pre-check.
  ctx.log.trace("Removing any existing symlink at \(destination)")
  try POSIX.unlink(destination)
  try POSIX.symlink(target: source, linkPath: destination)
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
func fileModificationDate(path: FilePath) -> Date? {
  guard let info = try? POSIX.stat(path) else { return nil }
  let ms = info.modificationDate.millisecondsSince1970
  return Date(milliseconds: ms - (ms % 1000))
}

/// Byte count of the file at `path`, or `nil` if the size cannot be read.
/// Used (together with `fileModificationDate`) as a cache key on `Photo`
/// so an unchanged source file can skip both hashing and EXIF/VIPS work.
func fileSizeInBytes(path: FilePath) -> Int? {
  guard let info = try? POSIX.stat(path) else { return nil }
  return Int(info.size)
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
