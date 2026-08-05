//
//  Photo.swift
//  g
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Foundation
import SystemPackage

struct Photo: Codable, Comparable, Hashable, Sendable {
  var name: String
  var url: GalleryURL
  var originalImageURL: GalleryURL
  var originalImagePath: FilePath
  var scaledPhotos: [ScaledPhoto]
  var parents: [Parent]

  // Metadata
  var aperture: Double?
  var apertureFormatted: String?
  var cameraMake: String?
  var cameraModel: String?
  var copyright: String?
  var dateTime: Date?
  var exposureTime: Double?
  var exposureTimeFormatted: String?
  var fNumber: Double?
  var fNumberFormatted: String?
  var focalLength: Double?
  var focalLengthFormatted: String?
  var gps: GPS?
  var height: Int?
  var imageDescription: String?
  var isoSpeed: Set<Int>
  var lensModel: String?
  var location: LocationData?
  var meteringMode: Int?
  var meteringModeFormatted: String?
  var modifiedDate: Date
  var orientation: Orientation?
  var owner: String?
  var shutterSpeed: Double?
  var shutterSpeedFormatted: String?
  var width: Int?

  /// Lowercase SHA-256 hex digest of the source image bytes at read time.
  /// Primary signal for incremental rebuilds: a photo is considered
  /// unchanged iff its source bytes are identical between runs.
  ///
  /// Optional so on-disk JSONs written before this field existed still
  /// decode cleanly. On the first rebuild after upgrade the on-disk value
  /// will be `nil` while the newly-read value will be a real hash, so
  /// every photo is treated as changed exactly once.
  var sourceHash: String?

  /// Size in bytes of the source image at read time. Paired with
  /// ``modifiedDate`` to form a cheap cache key: if `(fileSize,
  /// modifiedDate)` match what's on disk at the start of a later build,
  /// the source has not been touched at all and the full read
  /// (EXIF/VIPS/hash) can be skipped. Optional for on-disk back-compat.
  var fileSize: Int?

  /// Fingerprint of the config values that determine the encoded bytes
  /// of the scaled JPEGs (`jpegCompression` and `resolutions`). Derived
  /// from current `ctx.config` on every read, so a config change flows
  /// through `Photo.==` and re-encodes the affected outputs — the same
  /// way `scaledPhotos` already catches a `resolutions` change.
  ///
  /// Optional so on-disk JSONs written before this field existed still
  /// decode cleanly. On the first rebuild after upgrade the on-disk
  /// value will be `nil` while the newly-read value will be a real
  /// fingerprint, so every photo is treated as changed exactly once.
  var encodingFingerprint: String?

  var keywords: [KeywordPointer]
  var people: [KeywordPointer]
  /// Sibling navigation. Published like every other url, so it is relative
  /// to the gallery root rather than to wherever Munin wrote.
  var next: GalleryURL?
  var previous: GalleryURL?

  init(
    name: String,
    url: String,
    originalImageURL: String,
    originalImagePath: String,
    scaledPhotos: [ScaledPhoto],
    modifiedDate: Date,
    parents: [Parent]
  ) {
    self.init(
      name: name,
      url: GalleryURL(url),
      originalImageURL: GalleryURL(originalImageURL),
      originalImagePath: FilePath(originalImagePath),
      scaledPhotos: scaledPhotos,
      modifiedDate: modifiedDate,
      parents: parents)
  }

  init(
    name: String,
    url: GalleryURL,
    originalImageURL: GalleryURL,
    originalImagePath: FilePath,
    scaledPhotos: [ScaledPhoto],
    modifiedDate: Date,
    parents: [Parent]
  ) {
    self.name = name
    self.url = url
    self.originalImageURL = originalImageURL
    self.originalImagePath = originalImagePath
    self.scaledPhotos = scaledPhotos
    self.parents = parents
    self.modifiedDate = modifiedDate
    isoSpeed = []
    keywords = []
    people = []
  }

  // Intended for sort testing.
  init(
    name: String,
    dateTime: Date? = nil
  ) {
    self.name = name
    self.url = GalleryURL(FilePath())
    self.originalImageURL = GalleryURL(FilePath())
    self.originalImagePath = FilePath()
    self.scaledPhotos = []
    self.parents = []
    self.modifiedDate = Date()
    self.dateTime = dateTime
    isoSpeed = []
    keywords = []
    people = []
  }
}

struct ScaledPhoto: Codable, Equatable, Comparable, Sendable {
  var url: GalleryURL
  var maxResolution: Int

  init(url: String, maxResolution: Int) {
    self.url = GalleryURL(url)
    self.maxResolution = maxResolution
  }

  init(url: GalleryURL, maxResolution: Int) {
    self.url = url
    self.maxResolution = maxResolution
  }

  static func < (lhs: ScaledPhoto, rhs: ScaledPhoto) -> Bool {
    return lhs.maxResolution < rhs.maxResolution
  }
}

struct GPS: Codable, Sendable {
  var altitude: Double
  var latitude: Double
  var longitude: Double
}

struct LocationData: Codable, Equatable, Sendable {
  var city: String
  var state: String
  var locationCode: String
  var locationName: String
}

enum Orientation: String, Codable, Sendable {
  case landscape
  case portrait
}

/// Central home for domain constants that would otherwise appear as magic
/// strings scattered across the codebase.
enum PhotoConstants {
  /// Tagging a source photo with this keyword excludes it from the gallery.
  /// The name is historical — it originates from the Hugin panorama stitcher
  /// workflow — but is now just the agreed "do not publish" signal.
  static let excludeKeyword = "NO_HUGIN"
}

extension Photo {
  /// Strict total order over any set of photos with distinct `url`s.
  ///
  /// Totality is not decoration: every photo array Munin writes comes from
  /// `Array(someSet).sorted()`, and `sorted()` is stable, so any pair this
  /// cannot order keeps whatever order the `Set` iterated in — which is
  /// derived from the per-process randomised hash seed. A tie therefore
  /// leaks straight into `index.json`, `keywords/*.json` and
  /// `people/*.json`, and the same binary on the same input writes
  /// different bytes on the next run.
  ///
  /// Date, then name, then url. The first two are the ordering users see;
  /// url is the tie-break of last resort and is unique per photo (the
  /// build refuses to start otherwise, see `findOutputPathCollisions`).
  static func < (lhs: Photo, rhs: Photo) -> Bool {
    // Sort by date (exif, taken date) if it is available
    if let lhsDateTime = lhs.dateTime, let rhsDateTime = rhs.dateTime {
      // Taken at _exactly_ the same time: fall through to name.
      if lhsDateTime != rhsDateTime {
        return lhsDateTime < rhsDateTime
      }
    } else if lhs.dateTime != nil {
      // If only one has a date, consider that the winner
      return true
    } else if rhs.dateTime != nil {
      return false
    }

    if lhs.name != rhs.name {
      return lhs.name < rhs.name
    }

    // Equal names: either the same basename in two albums (legal, and
    // what `Keyword` aggregation collects across the gallery), or two
    // canonically-equivalent spellings of one name in one album, which
    // Swift's `String` comparison also considers equal.
    return canonicalThenBytewiseLess(lhs.url.string, rhs.url.string)
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(url)
  }
}

extension Photo {
  // MARK: - Computed Properties

  /// All files expected to exist on disk for this photo: JSON metadata, the
  /// symlinked original, and every scaled resolution.
  var expectedFiles: [URL] {
    let jsonURL = URL(fileURLWithPath: url.string)
    let symlinkedImageURL = URL(fileURLWithPath: originalImageURL.string)
    return [jsonURL, symlinkedImageURL] + scaledPhotos.map { URL(fileURLWithPath: $0.url.string) }
  }

  /// Depth of this photo's URL in the gallery hierarchy, measured in
  /// path components minus one (so a top-level photo has depth 0).
  var depth: Int {
    let n = url.path.components.count
    return n > 0 ? n - 1 : 0
  }

  /// Whether this photo should be included in the gallery. Photos tagged
  /// with `PhotoConstants.excludeKeyword` are excluded.
  var shouldInclude: Bool {
    !keywords.contains { $0.name == PhotoConstants.excludeKeyword }
  }
}

extension Photo: CustomStringConvertible {
  var description: String {
    return "Photo: \(name) modDate: \(modifiedDate))"
  }
}
