import Foundation
import SystemPackage
import Testing

@testable import MuninKit

/// The saver libvips runs is the operator's choice, not a fixed set:
/// `Imaging.scaleJPEG` names each output after its source file and
/// `fileExtensions` is user-configurable (`MUNIN_FILE_EXTENSIONS`), so any
/// format libvips can write may end up on the other side of `mv_save`.
///
/// libvips splits savers into those that declare a `Q` (quality) argument
/// and those where quality means nothing — the lossless and palette formats.
/// Passing `Q` to the latter is a hard error from `vips_call`, and a scale
/// that fails is *collected*, not fatal: the photo still appears in the
/// gallery JSON, pointing at a file that was never written. `mv_save`
/// therefore probes the saver class; these two tests pin both halves.
@Suite
struct ImagingSaveTests {

  /// Any small tracked source will do; this one is 42 KB.
  private static let source = FilePath("example/album/Misc/test_special_chars.jpg")

  /// PPM has no `Q` and, unlike GIF, is in every libvips build — no
  /// optional dependency sits behind it — so it stands in for the whole
  /// no-quality half.
  @Test func writesAFormatWhoseSaverHasNoQuality() throws {
    VIPSSetup.ensure()
    let directory = try Self.temporaryDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }

    let destination = FilePath(directory + "/scaled.ppm")
    let result = try Imaging.scaleJPEG(
      source: Self.source,
      destinations: [ScaleTarget(width: 64, path: destination)],
      quality: 60)

    #expect(result.failures.map(\.error.description).isEmpty)
    #expect(result.successes == [64])
    // Re-open it: proves a real image was written, not a truncated file.
    // libvips defaults a thumbnail's target height to its target width, so
    // the long edge is what lands on 64.
    let written = try Imaging.probe(source: destination)
    #expect(max(written.width, written.height) == 64)
  }

  /// The other half of the rule — dropping `Q` where it exists would be a
  /// silent quality regression no output-shape test would catch.
  @Test func honoursQualityWhereTheSaverHasIt() throws {
    VIPSSetup.ensure()
    let directory = try Self.temporaryDirectory()
    defer { try? FileManager.default.removeItem(atPath: directory) }

    var sizes: [Int: Int] = [:]
    for quality in [20, 95] {
      let destination = FilePath(directory + "/scaled-\(quality).jpg")
      let result = try Imaging.scaleJPEG(
        source: Self.source,
        destinations: [ScaleTarget(width: 256, path: destination)],
        quality: quality)
      #expect(result.failures.map(\.error.description).isEmpty)
      sizes[quality] = try Self.fileSize(destination.string)
    }

    #expect(sizes[95]! > sizes[20]!, "quality is not reaching the saver: \(sizes)")
  }

  // MARK: - Helpers

  private static func temporaryDirectory() throws -> String {
    let path =
      FileManager.default.temporaryDirectory
      .appendingPathComponent("munin-imaging-save-\(UUID().uuidString)", isDirectory: true).path
    try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
    return path
  }

  private static func fileSize(_ path: String) throws -> Int {
    let attributes = try FileManager.default.attributesOfItem(atPath: path)
    return (attributes[.size] as? Int) ?? 0
  }
}
