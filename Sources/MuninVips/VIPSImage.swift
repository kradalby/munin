import Cvips
import MuninVipsShim

/// Munin's libvips binding, in full.
///
/// Its own module, not a file inside MuninKit, so that reaching libvips
/// costs an `import MuninVips` — which is what makes the boundary a
/// compiler matter rather than a text audit. `ImagingFacadeTests` allows
/// that import in the `Imaging` facade and in `VIPSBootstrap`, nowhere else.
///
/// What Munin asks of libvips is listed once, in `MuninVipsShim.h`.
package enum VIPS {

  /// Initialise libvips. Must run before any other call in this module, and
  /// exactly once per process — `VIPSBootstrap` owns that once-ness and the
  /// no-shutdown policy.
  ///
  /// `argv[0]` is what libvips uses to locate its own prefix (ICC profiles,
  /// module directory). The static build ships all of that in the binary, so
  /// this only ever affects diagnostics.
  package static func start(concurrency: Int) throws {
    guard vips_init(CommandLine.arguments[0]) == 0 else { throw VIPSError() }
    vips_concurrency_set(Int32(concurrency))
  }

  /// Cap libvips' operation cache at nothing — no entries, no bytes, no open
  /// files — and, as a side effect of trimming to zero, evict what is in it.
  ///
  /// Entries are keyed by filename, so a process that rebuilds a path whose
  /// bytes changed underneath it must not be able to hit them.
  package static func disableOperationCache() {
    vips_cache_set_max(0)
    vips_cache_set_max_mem(0)
    vips_cache_set_max_files(0)
  }
}

/// Whatever libvips last wrote to its error buffer, drained.
///
/// `String(describing:)` on this reaches `description`, which is how the
/// libvips message ends up in `MuninError.imageOperationFailed(underlying:)`.
package struct VIPSError: Error, CustomStringConvertible {
  package let description: String

  package init() {
    // `_copy` rather than `vips_error_buffer()` followed by
    // `vips_error_clear()`: it reads and clears under libvips' own lock, so
    // one failing task cannot clear another's message between the read and
    // the clear. The buffer is still a single process-global string — two
    // tasks that both fail before either copies hand the first copier both
    // messages — but that is libvips' design, not something a caller fixes.
    let buffer: UnsafeMutablePointer<CChar>? = vips_error_buffer_copy()
    let message = buffer.map { String(cString: $0) } ?? ""
    g_free(buffer)
    // Empty rather than nil is the case that actually happens: the copy is a
    // `g_strdup` of the buffer and cannot fail, so an operation that failed
    // without writing a message arrives here as "".
    description = message.isEmpty ? "libvips failed without setting an error message" : message
  }
}

/// A libvips image handle.
///
/// `VipsImage` is a refcounted GObject. Both entry points that produce one
/// here — `mv_open` and `mv_thumbnail` — hand back a reference this class
/// takes ownership of and drops in `deinit`.
///
/// Deliberately **not** `Sendable`: libvips images are not safe to share
/// across tasks. Instances stay inside a single `Imaging` method body, a
/// boundary `ImagingFacadeTests` polices.
package final class VIPSImage {
  private let image: UnsafeMutablePointer<VipsImage>

  /// Adopts an already-owned reference; the caller must not unref it.
  private init(owning image: UnsafeMutablePointer<VipsImage>) {
    self.image = image
  }

  package init(fromFilePath path: String) throws {
    guard let image = mv_open(path) else { throw VIPSError() }
    self.image = image
  }

  deinit { g_object_unref(image) }

  package var width: Int { Int(vips_image_get_width(image)) }
  package var height: Int { Int(vips_image_get_height(image)) }
  package var orientationSwap: Bool { vips_image_get_orientation_swap(image) != 0 }

  package func thumbnailImage(width: Int) throws -> VIPSImage {
    var out: UnsafeMutablePointer<VipsImage>?
    guard mv_thumbnail(image, &out, Int32(width)) == 0, let out else {
      throw VIPSError()
    }
    return VIPSImage(owning: out)
  }

  package func writeToFile(_ path: String, quality: Int) throws {
    guard mv_save(image, path, Int32(quality)) == 0 else { throw VIPSError() }
  }
}
