import Foundation
import MuninVips
import SystemPackage

/// Munin's boundary against libvips. Every VIPS call in MuninKit goes
/// through `Imaging`; the binding itself is the separate `MuninVips` module,
/// so touching libvips costs an `import` that only this file and
/// `VIPSBootstrap` are allowed. That keeps libvips thread-safety assumptions
/// (non-`Sendable` class, shared process-wide worker pool, shared pipeline
/// cache) in one place.
///
/// The wider codebase only ever sees Sendable value types (`ImageProbe`,
/// `ScaleResult`) coming back out of these functions; no `VIPSImage`
/// escapes a method body.
enum Imaging {

  /// Read-only dimensions + orientation, computed once. A caller that
  /// needs width/height/orientation without any scaling wants this —
  /// `Photo+Read` uses it to populate `Photo.width`, `Photo.height`,
  /// and `Photo.orientation`.
  static func probe(source: FilePath) throws -> ImageProbe {
    let image: VIPSImage
    do {
      image = try VIPSImage(fromFilePath: source.string)
    } catch {
      throw MuninError.imageOperationFailed(
        path: source.string, operation: "open", underlying: String(describing: error))
    }
    VIPSBootstrap.didRunPipeline()
    return ImageProbe(
      width: image.width,
      height: image.height,
      orientationSwap: image.orientationSwap)
  }

  /// Render one or more scaled JPEG outputs from a single source image.
  ///
  /// The source is opened exactly once — callers pass every target
  /// `(width, destination)` they need so libvips doesn't re-read the
  /// source per size. Opening is the expensive part (decoding the
  /// source JPEG); scaling is a cheap pipeline operation on the
  /// decoded image.
  ///
  /// Failure model:
  /// - Source-open failure is fatal for the whole photo and is thrown
  ///   as `MuninError.imageOperationFailed(operation: "open", …)`.
  /// - Per-destination scale/write failures are collected on the
  ///   returned `ScaleResult` rather than thrown, so a single corrupt
  ///   thumbnail doesn't drop the other resolutions — the caller
  ///   decides whether to log, summarise, or promote them.
  @discardableResult
  static func scaleJPEG(
    source: FilePath,
    destinations: [ScaleTarget],
    quality: Int
  ) throws -> ScaleResult {
    let image: VIPSImage
    do {
      image = try VIPSImage(fromFilePath: source.string)
    } catch {
      throw MuninError.imageOperationFailed(
        path: source.string, operation: "open", underlying: String(describing: error))
    }
    VIPSBootstrap.didRunPipeline()

    var result = ScaleResult()
    for target in destinations {
      do {
        try image.thumbnailImage(width: target.width)
          .writeToFile(target.path.string, quality: quality)
        result.successes.append(target.width)
      } catch {
        result.failures.append(
          ScaleFailure(
            width: target.width,
            destination: target.path,
            error: .imageOperationFailed(
              path: target.path.string,
              operation: "thumbnail",
              underlying: String(describing: error))))
      }
    }
    return result
  }
}

/// Dimensions + display orientation for a source image. Populated by
/// `Imaging.probe(source:)`; carries no libvips handle, so it crosses
/// task boundaries freely.
struct ImageProbe: Sendable, Equatable {
  let width: Int
  let height: Int
  /// EXIF orientations 5–8 imply a 90/270° rotation that swaps the
  /// visual width and height. Pre-computed here so the caller doesn't
  /// re-derive it from the raw EXIF tag.
  let orientationSwap: Bool
}

/// One output requested from `Imaging.scaleJPEG`.
struct ScaleTarget: Sendable, Equatable {
  let width: Int
  let path: FilePath
}

/// Outcome of an `Imaging.scaleJPEG` call.
struct ScaleResult: Sendable {
  var successes: [Int] = []
  var failures: [ScaleFailure] = []
}

struct ScaleFailure: Sendable {
  let width: Int
  let destination: FilePath
  let error: MuninError
}
