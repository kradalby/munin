import Cvips
import Foundation
import VIPS

/// Centralised, idempotent one-shot VIPS initialisation.
///
/// `VIPS.start(concurrency:)` must be called exactly once per process before
/// any `VIPSImage` operation, but libvips does not tolerate being re-started
/// or shut down cleanly while its worker threads are still active. To keep
/// this simple, MuninKit owns a single bootstrap helper that:
///
/// 1. Runs `VIPS.start(...)` on the first call only (guarded by a Swift
///    static-let initialiser, which the runtime guarantees to be executed at
///    most once).
/// 2. Caches whatever concurrency value was used. Subsequent calls are
///    no-ops; the `concurrency:` argument is ignored on repeat calls.
/// 3. Deliberately does *not* call `VIPS.shutdown()`. The OS will reclaim
///    libvips worker threads at process exit; attempting a graceful shutdown
///    races against those threads and crashes in practice.
///
/// Usage:
/// ```swift
/// // From the CLI:
/// try VIPSBootstrap.start(concurrency: config.concurrency)
///
/// // From tests:
/// try VIPSBootstrap.start(concurrency: 1)
/// ```
public enum VIPSBootstrap {

  /// Initialise VIPS on the first call; subsequent calls are no-ops.
  ///
  /// - Parameter concurrency: Forwarded to `VIPS.start(concurrency:)` on the
  ///   first call. Ignored on subsequent calls.
  /// - Throws: Any error thrown by the underlying `VIPS.start(concurrency:)`
  ///   on the first call.
  public static func start(concurrency: Int) throws {
    try Bootstrap.shared.ensure(concurrency: concurrency)
  }

  /// For tests: stable single-threaded VIPS setup, with malloc-only GLib
  /// allocator and disabled disk cache. Safe to call from multiple test
  /// cases — only the first invocation does anything.
  public static func startForTesting() {
    // Disable libvips' on-disk threshold and operation cache for determinism.
    setenv("G_SLICE", "always-malloc", 1)
    setenv("VIPS_DISC_THRESHOLD", "0", 1)
    setenv("VIPS_CACHE_MAX", "0", 1)
    do {
      try start(concurrency: 1)
    } catch {
      fatalError("Failed to initialize VIPS for tests: \(error)")
    }
    // Env var alone isn't enough on every libvips release; belt-and-braces
    // the cache cap via the C API so repeated in-process builds of the
    // same source path don't return stale cached pixel data.
    vips_cache_set_max(0)
    vips_cache_set_max_mem(0)
    vips_cache_set_max_files(0)
  }

  /// Drop libvips' operation cache. Tests that re-run a build against
  /// the same source paths after replacing the underlying bytes need to
  /// call this between builds; otherwise libvips may return cached pixel
  /// data keyed by filename, not content, and the second build produces
  /// byte-identical output to the first.
  ///
  /// No-op on the first call — libvips initialises its cache hash table
  /// lazily on the first operation, so `vips_cache_drop_all()` before any
  /// operation dereferences a null pointer and crashes the process. We
  /// track whether any pipeline has run via an internal flag and gate the
  /// drop on that; call ``didRunPipeline()`` from VIPS code paths to
  /// flip it.
  public static func dropPipelineCache() {
    Bootstrap.shared.dropCacheIfInitialised()
  }

  /// Tell the bootstrap helper that a libvips pipeline has run at least
  /// once. Called from the Munin read/write paths so subsequent
  /// ``dropPipelineCache()`` calls know the cache hash table exists.
  public static func didRunPipeline() {
    Bootstrap.shared.markPipelineRan()
  }
}

private final class Bootstrap: @unchecked Sendable {
  static let shared = Bootstrap()
  private let lock = NSLock()
  private var started = false
  private var startError: Error?
  private var pipelineRan = false

  private init() {}

  func ensure(concurrency: Int) throws {
    lock.lock()
    defer { lock.unlock() }
    if started {
      if let error = startError {
        throw error
      }
      return
    }
    do {
      try VIPS.start(concurrency: concurrency)
      started = true
    } catch {
      startError = error
      started = true
      throw error
    }
  }

  func markPipelineRan() {
    lock.lock()
    defer { lock.unlock() }
    pipelineRan = true
  }

  func dropCacheIfInitialised() {
    lock.lock()
    defer { lock.unlock() }
    guard pipelineRan else { return }
    // `vips_cache_drop_all` dereferences a potentially-null hash table on
    // some libvips builds when the operation cache has been disabled via
    // `VIPS_CACHE_MAX=0` but never used. `vips_error_clear` is the
    // safer-but-equivalent hammer for the symptom we care about: stale
    // per-filename pixel data surviving across builds.
    //
    // `vips_cache_set_max(0)` re-applies the cap; it also flushes the
    // cache as a side-effect of trimming to zero entries (when the cache
    // has entries to trim).
    vips_cache_set_max(0)
    vips_cache_set_max_mem(0)
    vips_cache_set_max_files(0)
  }
}
