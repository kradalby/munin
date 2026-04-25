import Foundation
import SwiftExif
import SystemPackage

/// EXIF + IPTC reads on the same `Imaging` facade as the VIPS calls.
/// `SwiftExif.Image.parse(at:)` already returns a Sendable `ExifResult`,
/// so the facade is a thin wrapper — its only job is to keep the
/// SwiftExif import contained inside `IO/Imaging/` (enforced by
/// `ImagingFacadeTests`).
extension Imaging {

  /// Read EXIF + IPTC in one pass. `SwiftExif.parse(at:)` only throws
  /// `ParseError.fileUnreadable`, which in Munin's flow is racing the
  /// directory walker — the VIPS probe on the same path will surface
  /// the same condition with a richer error, so we swallow it here
  /// and return an empty result. A source without a proper EXIF block
  /// is still a valid photo, just one with fewer populated `Photo`
  /// fields.
  static func readExif(source: FilePath) -> ExifResult {
    do {
      return try SwiftExif.Image.parse(at: URL(fileURLWithPath: source.string))
    } catch {
      return ExifResult(exif: [:], exifRaw: [:], iptc: IptcFields(), orientation: nil)
    }
  }
}
