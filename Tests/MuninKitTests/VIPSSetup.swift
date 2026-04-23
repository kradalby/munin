import Foundation

@testable import MuninKit

/// Test-side wrapper that delegates to `MuninKit.VIPSBootstrap`.
///
/// Keeps the existing `VIPSSetup.ensure()` call sites in the test suite
/// stable while the real bootstrap logic lives in the library alongside
/// the production `VIPSBootstrap.start(concurrency:)`.
enum VIPSSetup {
  /// Call from test `setUp()` to ensure VIPS is initialised exactly once
  /// per test process, configured for deterministic single-threaded use.
  static func ensure() {
    VIPSBootstrap.startForTesting()
  }
}
