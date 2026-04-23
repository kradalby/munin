import Foundation
import VIPS

/// One-shot VIPS initialization for the test process.
///
/// Swift's thread-safe static-let initialization guarantees this runs at most
/// once even when called from multiple test cases concurrently.
///
/// We intentionally do **not** call `VIPS.shutdown()` on teardown. Doing so
/// causes SIGSEGV because libvips worker threads may still be active. Process
/// exit cleans up the resources.
enum VIPSSetup {
  private static let initialized: Void = {
    // Stable test environment: no disk cache, single-threaded, malloc-only.
    setenv("G_SLICE", "always-malloc", 1)
    setenv("VIPS_DISC_THRESHOLD", "0", 1)
    setenv("VIPS_CACHE_MAX", "0", 1)
    do {
      try VIPS.start(concurrency: 1)
    } catch {
      fatalError("Failed to initialize VIPS for tests: \(error)")
    }
  }()

  /// Call from test `setUp()` to ensure VIPS is initialized once.
  static func ensure() {
    _ = initialized
  }
}
