import Foundation
import SystemPackage

/// Internal path-manipulation helpers backed by `apple/swift-system`'s
/// `FilePath`.
///
/// Public-facing API remains `String`-based so that on-disk JSON (which
/// contains path strings) does not change format. The goal here is to get
/// the benefits of `FilePath`'s typed path arithmetic inside the helpers
/// without rippling into every caller. FUTURES.md tracks extending
/// `FilePath` adoption further (Scope B/C).
enum Paths {
  /// Join path components, trimming redundant separators on each component
  /// but preserving a leading `/` on the first component when present.
  ///
  /// This is the workhorse helper used throughout MuninKit to build URLs
  /// and on-disk paths from `outPath + name + filename`-style chains.
  static func join(_ components: [String]) -> String {
    let nonEmpty = components.filter { !$0.isEmpty }
    guard let first = nonEmpty.first else { return "" }

    var filePath = FilePath()
    if first.hasPrefix("/") {
      filePath = FilePath("/")
    }
    for raw in nonEmpty {
      let trimmed = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      guard !trimmed.isEmpty else { continue }
      filePath.append(trimmed)
    }
    return filePath.string
  }

  /// Last path component with its extension stripped.
  static func stem(_ path: String) -> String {
    FilePath(path).stem ?? ""
  }

  /// Path's file extension without the leading dot (e.g. `"jpg"`), or `nil`
  /// if there is no extension.
  static func `extension`(_ path: String) -> String? {
    FilePath(path).extension
  }

  /// Make a string safe for use as a URL component by replacing spaces with
  /// underscores. Kept here (rather than in `FilePath`) because it encodes a
  /// MuninKit-specific display convention.
  static func urlify(_ name: String) -> String {
    name.replacingOccurrences(of: " ", with: "_")
  }
}
