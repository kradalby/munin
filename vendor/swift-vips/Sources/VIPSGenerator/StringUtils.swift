//
//  StringUtils.swift
//  VIPSGenerator
//
//  String utility functions for code generation
//

/// Convert snake_case to camelCase
/// - Parameter name: The snake_case string to convert
/// - Returns: camelCase version of the string
///
/// The first component stays lowercase, subsequent components are capitalized.
/// Example: `extract_area` → `extractArea`
func snakeToCamel(_ name: String) -> String {
    let components = name.split(separator: "_")

    if components.isEmpty {
        return name
    }

    // First component preserves its case, rest are capitalized
    return String(components[0]) + components[1...].map { $0.capitalized }.joined()
}

/// Convert parameter name to Swift-safe version
/// - Parameter name: The parameter name to convert
/// - Returns: Swift-safe parameter name
///
/// Handles special mappings, replaces hyphens with underscores,
/// converts to camelCase, and escapes Swift keywords with backticks.
/// Example: `in` → `` `in` ``
func swiftizeParam(_ name: String) -> String {
    var result = name

    // Handle special parameter name mappings
    if result == "Q" {
        return "quality"
    }

    // Replace hyphens with underscores
    result = result.replacingOccurrences(of: "-", with: "_")

    // Convert to camelCase
    result = snakeToCamel(result)

    // Escape if it's a keyword
    if swiftKeywords.contains(result) {
        return "`\(result)`"
    }

    return result
}
