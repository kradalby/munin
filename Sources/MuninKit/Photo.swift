//
//  Photo.swift
//  g
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Foundation

struct Photo: Codable, Comparable, Hashable, Diffable, Sendable {
  var name: String
  var url: String
  var originalImageURL: String
  var originalImagePath: String
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
  var next: String?
  var previous: String?

  init(
    name: String,
    url: String,
    originalImageURL: String,
    originalImagePath: String,
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
    self.url = ""
    self.originalImageURL = ""
    self.originalImagePath = ""
    self.scaledPhotos = []
    self.parents = []
    self.modifiedDate = Date()
    self.dateTime = dateTime
    isoSpeed = []
    keywords = []
    people = []
  }
}

struct ScaledPhoto: Codable, AutoEquatable, Comparable, Sendable {
  var url: String
  var maxResolution: Int

  static func < (lhs: ScaledPhoto, rhs: ScaledPhoto) -> Bool {
    return lhs.maxResolution < rhs.maxResolution
  }
}

struct GPS: Codable, AutoEquatable, Sendable {
  var altitude: Double
  var latitude: Double
  var longitude: Double
}

struct LocationData: Codable, AutoEquatable, Sendable {
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

extension Photo: AutoEquatable {
  static func < (lhs: Photo, rhs: Photo) -> Bool {
    // Sort by date (exif, taken date) if it is available
    if let lhsDateTime = lhs.dateTime, let rhsDateTime = rhs.dateTime {

      // If taken at _exactly_ the same time, use name
      if lhsDateTime == rhsDateTime {
        return lhs.name < rhs.name
      }

      return lhsDateTime < rhsDateTime
    }

    // If only one has a date, consider that the winner
    if lhs.dateTime != nil {
      return true
    }

    if rhs.dateTime != nil {
      return false
    }

    // Fallback to name
    return lhs.name < rhs.name
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
    let jsonURL = URL(fileURLWithPath: url)
    let symlinkedImageURL = URL(fileURLWithPath: originalImageURL)
    return [jsonURL, symlinkedImageURL] + scaledPhotos.map { URL(fileURLWithPath: $0.url) }
  }

  /// Depth of this photo's URL in the gallery hierarchy, measured by
  /// `/` separators.
  var depth: Int {
    url.filter { $0 == "/" }.count
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
