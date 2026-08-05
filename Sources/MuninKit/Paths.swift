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

  /// Re-express `path` relative to `base`, or return it unchanged when it
  /// does not sit under `base`.
  ///
  /// Munin builds a published URL and the on-disk path it writes to from
  /// the same string, so every emitted URL carries the name of the output
  /// directory (`Configuration.targetFolder`). Relativizing at the
  /// serialization boundary lets disk writes keep the full path while the
  /// published gallery stays portable: a consumer can then serve it from
  /// any prefix without agreeing on that directory's name.
  ///
  /// Matching is component-wise, so `hugin2/a` is not considered to sit
  /// under `hugin`. A relative path never matches an absolute base, or
  /// vice versa.
  static func relative(_ path: String, to base: String) -> String {
    let basePath = FilePath(base)
    let baseComponents = basePath.components.map(\.string)
    guard !baseComponents.isEmpty else { return path }

    let filePath = FilePath(path)
    guard filePath.root == basePath.root else { return path }

    let components = filePath.components.map(\.string)
    guard components.count >= baseComponents.count,
      Array(components.prefix(baseComponents.count)) == baseComponents
    else { return path }

    return join(Array(components.dropFirst(baseComponents.count)))
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
