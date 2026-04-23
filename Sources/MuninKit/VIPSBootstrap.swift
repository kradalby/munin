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
  }
}

private final class Bootstrap: @unchecked Sendable {
  static let shared = Bootstrap()
  private let lock = NSLock()
  private var started = false
  private var startError: Error?

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
}
