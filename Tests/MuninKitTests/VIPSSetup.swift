import Foundation
import VIPS
import Cvips

// Global VIPS initialization for all tests
// This ensures VIPS is initialized only once per test process
public class VIPSSetup {
    // Use dispatch_once equivalent for thread-safe initialization
    private static let vipsInitialized: Void = {
        // Set environment variables for stable VIPS operation
        setenv("G_SLICE", "always-malloc", 1)
        setenv("VIPS_DISC_THRESHOLD", "0", 1)  // Disable disk operations
        setenv("VIPS_CACHE_MAX", "0", 1)      // Disable cache

        do {
            // Start VIPS with concurrency 1 for stable testing
            try VIPS.start(concurrency: 1)

            // NOTE: We intentionally do NOT call VIPS.shutdown() or vips_thread_shutdown()
            // in tests. Calling these functions causes crashes because libvips worker
            // threads may still be active. In a test environment, it's acceptable to
            // let the OS clean up these resources when the process exits.
            // The main application in main.swift does not have this issue because
            // all VIPS operations complete before the process exits naturally.
        } catch {
            fatalError("Failed to initialize VIPS for tests: \(error)")
        }
    }()

    public static func initialize() {
        // Force initialization by accessing the computed property
        _ = vipsInitialized
    }
}