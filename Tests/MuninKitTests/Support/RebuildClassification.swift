import Foundation

/// Semantic grouping of a ``FilesystemSnapshot.Diff`` by the kind of
/// output Munin emits, so rebuild scenarios can reason about "how many
/// scaled images got re-encoded" or "which photo JSONs changed" without
/// re-deriving the filter every time.
///
/// The categories are defined by filename convention (and symlink
/// status):
///
/// - Scaled images: `<stem>_<NNN>.<ext>` regular files (jpg/jpeg/JPG/JPEG).
/// - Original symlinks: `<stem>_original.<ext>` symlink entries.
/// - Photo JSONs: non-`index.json` / non-`stats.json` / non-`locations.json`
///   `.json` files under the gallery root.
/// - Album indexes: every `index.json`.
/// - Top-level files: `stats.json` and `locations.json` at the gallery root.
/// - Keyword JSONs: any `.json` under `keywords/`.
///
/// Each category is paired with a sorted `[String]` so failure messages
/// list paths predictably.
struct RebuildClassification {
  let scaledImagesReencoded: [String]
  let scaledImagesRewrittenSameBytes: [String]
  let originalSymlinksAdded: [String]
  let originalSymlinksRemoved: [String]
  let photoJsonsByteChanged: [String]
  let photoJsonsRewrittenSameBytes: [String]
  let albumIndexesByteChanged: [String]
  let topLevelFilesByteChanged: [String]
  let keywordJsonsByteChanged: [String]
  /// Any entry not matched by a more specific category. Non-empty here
  /// signals an unexpected output shape and is worth inspecting.
  let otherChanges: [String]

  init(
    from diff: FilesystemSnapshot.Diff,
    before: FilesystemSnapshot,
    after: FilesystemSnapshot
  ) {
    var scaledReencoded: [String] = []
    var scaledRewritten: [String] = []
    var symlinksAdded: [String] = []
    var symlinksRemoved: [String] = []
    var photoJsonsChanged: [String] = []
    var photoJsonsRewritten: [String] = []
    var albumIndexesChanged: [String] = []
    var topLevelChanged: [String] = []
    var keywordJsonsChanged: [String] = []
    var other: [String] = []

    for path in diff.byteChanged {
      switch Self.classify(path: path, in: after) {
      case .scaledImage:
        scaledReencoded.append(path)
      case .symlink:
        // Byte-changed on a symlink means the target moved. Treat it as
        // symlink-related rather than image-related.
        symlinksAdded.append(path)
      case .photoJson:
        photoJsonsChanged.append(path)
      case .albumIndex:
        albumIndexesChanged.append(path)
      case .keywordJson:
        keywordJsonsChanged.append(path)
      case .topLevelFile:
        topLevelChanged.append(path)
      case .other:
        other.append(path)
      }
    }
    for path in diff.rewrittenIdentical {
      switch Self.classify(path: path, in: after) {
      case .scaledImage:
        scaledRewritten.append(path)
      case .photoJson:
        photoJsonsRewritten.append(path)
      case .albumIndex, .keywordJson, .topLevelFile, .symlink, .other:
        // Not interesting for assertion purposes — rewriting JSONs with
        // identical bytes is expected on every rebuild today.
        break
      }
    }
    for path in diff.added {
      switch Self.classify(path: path, in: after) {
      case .symlink:
        symlinksAdded.append(path)
      case .scaledImage:
        scaledReencoded.append(path)
      case .photoJson:
        photoJsonsChanged.append(path)
      case .albumIndex:
        albumIndexesChanged.append(path)
      case .keywordJson:
        keywordJsonsChanged.append(path)
      case .topLevelFile:
        topLevelChanged.append(path)
      case .other:
        other.append(path)
      }
    }
    for path in diff.removed {
      switch Self.classify(path: path, in: before) {
      case .symlink:
        symlinksRemoved.append(path)
      case .scaledImage:
        // A scaled image being removed means libvips output went away —
        // record it alongside re-encodes for assertion convenience.
        scaledReencoded.append(path)
      case .photoJson:
        photoJsonsChanged.append(path)
      case .albumIndex:
        albumIndexesChanged.append(path)
      case .keywordJson:
        keywordJsonsChanged.append(path)
      case .topLevelFile:
        topLevelChanged.append(path)
      case .other:
        other.append(path)
      }
    }

    self.scaledImagesReencoded = scaledReencoded.sorted()
    self.scaledImagesRewrittenSameBytes = scaledRewritten.sorted()
    self.originalSymlinksAdded = symlinksAdded.sorted()
    self.originalSymlinksRemoved = symlinksRemoved.sorted()
    self.photoJsonsByteChanged = photoJsonsChanged.sorted()
    self.photoJsonsRewrittenSameBytes = photoJsonsRewritten.sorted()
    self.albumIndexesByteChanged = albumIndexesChanged.sorted()
    self.topLevelFilesByteChanged = topLevelChanged.sorted()
    self.keywordJsonsByteChanged = keywordJsonsChanged.sorted()
    self.otherChanges = other.sorted()
  }

  /// Compact multi-line summary suitable for a failing-test message.
  var summary: String {
    """
    scaledImagesReencoded=\(scaledImagesReencoded.count) \(scaledImagesReencoded.prefix(3))
    scaledImagesRewrittenSameBytes=\(scaledImagesRewrittenSameBytes.count) \(scaledImagesRewrittenSameBytes.prefix(3))
    originalSymlinksAdded=\(originalSymlinksAdded.count) \(originalSymlinksAdded.prefix(3))
    originalSymlinksRemoved=\(originalSymlinksRemoved.count) \(originalSymlinksRemoved.prefix(3))
    photoJsonsByteChanged=\(photoJsonsByteChanged.count)
    albumIndexesByteChanged=\(albumIndexesByteChanged.count)
    topLevelFilesByteChanged=\(topLevelFilesByteChanged.count) \(topLevelFilesByteChanged)
    keywordJsonsByteChanged=\(keywordJsonsByteChanged.count)
    otherChanges=\(otherChanges.count) \(otherChanges.prefix(3))
    """
  }

  // MARK: - Path classification

  private enum Category {
    case scaledImage
    case symlink
    case photoJson
    case albumIndex
    case keywordJson
    case topLevelFile
    case other
  }

  private static let imageExtensions: Set<String> = ["jpg", "jpeg", "JPG", "JPEG"]
  private static let topLevelJsonNames: Set<String> = ["stats.json", "locations.json"]

  private static func classify(path: String, in snapshot: FilesystemSnapshot) -> Category {
    if let entry = snapshot.entries[path], entry.kind == .symlink {
      return .symlink
    }

    let url = URL(fileURLWithPath: path)
    let filename = url.lastPathComponent

    if path.hasPrefix("keywords/"), filename.hasSuffix(".json") {
      return .keywordJson
    }

    if filename == "index.json" {
      return .albumIndex
    }

    if topLevelJsonNames.contains(filename) {
      return .topLevelFile
    }

    let ext = url.pathExtension
    if imageExtensions.contains(ext) {
      // Convention: `<stem>_<NNN>.<ext>` is a scaled variant; anything
      // else (e.g. the never-present raw filename, or an unexpected
      // image at root) falls to `other`.
      let stem = url.deletingPathExtension().lastPathComponent
      if stem.contains("_") && !stem.hasSuffix("_original") {
        return .scaledImage
      }
      return .other
    }

    if filename.hasSuffix(".json") {
      return .photoJson
    }

    return .other
  }
}
