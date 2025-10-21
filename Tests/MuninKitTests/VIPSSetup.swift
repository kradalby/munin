import Foundation
import VIPS

// Global VIPS initialization for all tests
// This ensures VIPS is initialized only once per test process
public class VIPSSetup {
    private static let initializationQueue = DispatchQueue(label: "vips.init")
    
    // Use dispatch_once equivalent for thread-safe initialization
    private static let vipsInitialized: Void = {
        // Set environment variables for stable VIPS operation
        setenv("G_SLICE", "always-malloc", 1)
        setenv("VIPS_DISC_THRESHOLD", "0", 1)  // Disable disk operations
        setenv("VIPS_CACHE_MAX", "0", 1)      // Disable cache
        
        do {
            // Start VIPS with concurrency 1 for stable testing
            try VIPS.start(concurrency: 1)
        } catch {
            fatalError("Failed to initialize VIPS for tests: \(error)")
        }
    }()
    
    public static func initialize() {
        // Force initialization by accessing the computed property
        _ = vipsInitialized
    }
}