import Foundation
import SwiftExif
import SystemPackage

/// EXIF + IPTC reads on the same `Imaging` facade as the VIPS calls.
/// Direct `SwiftExif.Image` use lives only in this file so the
/// non-`Sendable` struct stays contained; callers only ever see the
/// Sendable `ExifSnapshot` value type.
extension Imaging {

  /// Read EXIF + IPTC in one pass. Errors from SwiftExif surface as
  /// empty sub-dictionaries, matching today's "no EXIF / no IPTC is
  /// fine" behaviour — a source without a proper EXIF block is still a
  /// valid photo, just one with fewer populated `Photo` fields.
  static func readExif(source: FilePath) -> ExifSnapshot {
    let image = SwiftExif.Image(imagePath: URL(fileURLWithPath: source.string))

    var iptcStrings: [String: String] = [:]
    var iptcKeywords: [String] = []
    for (key, value) in image.Iptc() {
      if let str = value as? String {
        iptcStrings[key] = str
      } else if key == iptcKeywordsKey, let list = value as? [String] {
        iptcKeywords = list
      }
    }

    return ExifSnapshot(
      exif: image.Exif(),
      exifRaw: image.ExifRaw(),
      iptcStrings: iptcStrings,
      iptcKeywords: iptcKeywords)
  }

  /// SwiftExif's key for the IPTC "Keywords" field.
  private static let iptcKeywordsKey = "Keywords"
}

/// Bundled EXIF + IPTC read from a single source. Sendable value type;
/// can cross task boundaries without any unsafe escape hatches.
struct ExifSnapshot: Sendable {
  /// Human-readable EXIF values, keyed `[ifd][tag]`. Matches
  /// `SwiftExif.Image.Exif()`.
  let exif: [String: [String: String]]

  /// Raw EXIF values, keyed `[ifd][tag]`. Matches
  /// `SwiftExif.Image.ExifRaw()`.
  let exifRaw: [String: [String: String]]

  /// IPTC fields whose values are plain strings — City, Province/State,
  /// Country Code, Country Name, etc. Pre-separated from `iptcKeywords`
  /// so the caller doesn't have to do `as? String` / `as? [String]`
  /// coercions on `Any`.
  let iptcStrings: [String: String]

  /// IPTC "Keywords" field, normalised to an array. Empty when absent.
  let iptcKeywords: [String]
}
