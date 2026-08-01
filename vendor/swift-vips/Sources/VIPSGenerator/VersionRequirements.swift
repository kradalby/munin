//
//  VersionRequirements.swift
//  VIPSGenerator
//
//  Operations that require specific libvips versions
//

/// Maps version strings to operations that require that version
let versionRequirements: [String: [String]] = [
    "8.13": ["premultiply", "unpremultiply"],
    "8.16": ["addalpha"],
    "8.17": ["sdf_shape", "sdf"]
]

/// Get the version guard for an operation if it requires a specific version
/// - Parameter nickname: The operation nickname
/// - Returns: The preprocessor guard string (e.g., "#if SHIM_VIPS_VERSION_8_16") or nil
func getOperationVersionGuard(_ nickname: String) -> String? {
    for (version, operations) in versionRequirements {
        if operations.contains(nickname) {
            return "#if SHIM_VIPS_VERSION_\(version.replacingOccurrences(of: ".", with: "_"))"
        }
    }
    return nil
}
