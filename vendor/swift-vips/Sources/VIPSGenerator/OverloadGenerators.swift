//
//  OverloadGenerators.swift
//  VIPSGenerator
//
//  Generate various overloads for VIPS operations
//

import Cvips
import CvipsShim
import Foundation
import VIPSIntrospection

/// Generates various overloads for VIPS operations including const overloads,
/// buffer overloads, and convenience methods
struct OverloadGenerators {

    // MARK: - Simple Const Overloads

    /// Generate simple const overloads (Double, Int) for _const operations
    ///
    /// For operations like `remainder_const` that take a 'c' parameter,
    /// this generates convenience overloads that accept single Double or Int values.
    ///
    /// - Parameters:
    ///   - baseOp: Name of the base operation (e.g., "remainder")
    ///   - constOp: Details of the const variant operation (e.g., "remainder_const")
    /// - Returns: Array of Swift method strings
    func generateSimpleConstOverloads(baseOp: String, constOp: VIPSOperationDetails) -> [String] {
        // Skip if operation is deprecated
        if constOp.isDeprecated {
            return []
        }

        // Only generate for image output operations
        let requiredOutput = constOp.requiredOutput.filter { $0 != constOp.memberX }
        guard let firstOutput = requiredOutput.first,
              let outputParam = constOp.parameters[firstOutput],
              outputParam.parameterType == vips_image_get_type() else {
            return []
        }

        // Only generate for operations with a 'c' parameter
        guard constOp.methodArgs.contains("c") || constOp.optionalInput.contains("c") else {
            return []
        }

        var funcName = snakeToCamel(baseOp)
        if swiftKeywords.contains(funcName) {
            funcName = "`\(funcName)`"
        }

        let constFuncName = snakeToCamel(constOp.nickname)

        var overloads: [String] = []

        // Generate Double overload
        var result: [String] = []
        result.append("    /// \(constOp.description.prefix(1).uppercased())\(constOp.description.dropFirst())")
        result.append("    ///")
        result.append("    /// - Parameters:")
        result.append("    ///   - value: Constant value")
        result.append("    public func \(funcName)(_ value: Double) throws -> Self {")
        result.append("        return try \(constFuncName)(c: [value])")
        result.append("    }")
        overloads.append(result.joined(separator: "\n"))

        // Generate Int overload
        result = []
        result.append("    /// \(constOp.description.prefix(1).uppercased())\(constOp.description.dropFirst())")
        result.append("    ///")
        result.append("    /// - Parameters:")
        result.append("    ///   - value: Constant value")
        result.append("    public func \(funcName)(_ value: Int) throws -> Self {")
        result.append("        return try \(constFuncName)(c: [Double(value)])")
        result.append("    }")
        overloads.append(result.joined(separator: "\n"))

        return overloads
    }

    // MARK: - VIPSBlob Overload

    /// Generate VIPSBlob overload for buffer operations
    ///
    /// Creates an overload that accepts VIPSBlob for buffer-based load operations.
    ///
    /// - Parameter details: Operation details
    /// - Returns: Swift method string, or nil if not applicable
    func generateVIPSBlobOverload(for details: VIPSOperationDetails) -> String? {
        // Skip deprecated operations
        if details.isDeprecated {
            return nil
        }

        // Find the blob parameter
        guard let blobParamName = findBlobParameter(in: details) else {
            return nil
        }

        // Only generate for image output operations
        let requiredOutput = details.requiredOutput.filter { $0 != details.memberX }
        guard let firstOutput = requiredOutput.first,
              let outputParam = details.parameters[firstOutput],
              outputParam.parameterType == vips_image_get_type() else {
            return nil
        }

        // Filter out deprecated and internal parameters
        let optionalInput = details.optionalInput.filter { name in
            guard let param = details.parameters[name] else { return false }
            return !param.isDeprecated && name != "nickname" && name != "description"
        }

        var result: [String] = []

        // Generate documentation
        result.append("    /// \(details.description.prefix(1).uppercased())\(details.description.dropFirst())")

        // Add parameter documentation
        let allParams = details.methodArgs + optionalInput
        if !allParams.isEmpty {
            result.append("    ///")
            result.append("    /// - Parameters:")
            for name in allParams {
                if let param = details.parameters[name] {
                    let paramName = swiftizeParam(name)
                    if name == blobParamName {
                        result.append("    ///   - \(paramName): Buffer to load from")
                    } else {
                        result.append("    ///   - \(paramName): \(param.description)")
                    }
                }
            }
        }

        // Build function signature
        var funcName = snakeToCamel(details.nickname)

        // Remove common suffixes for overloaded methods
        let overloadSuffixes = ["Buffer", "Source", "Target", "Mime"]
        for suffix in overloadSuffixes {
            if funcName.hasSuffix(suffix) {
                funcName = String(funcName.dropLast(suffix.count))
                break
            }
        }

        if swiftKeywords.contains(funcName) {
            funcName = "`\(funcName)`"
        }

        let isLoadOp = details.nickname.contains("load")
        let methodType = isLoadOp ? "public static func" : "public func"

        var signature = "    \(methodType) \(funcName)("

        // Add required parameters
        var params: [String] = []
        var isFirstParam = true
        for name in details.methodArgs {
            if name == details.memberX {
                continue
            }

            guard let param = details.parameters[name] else { continue }
            let paramName = swiftizeParam(name)

            // Use VIPSBlob for the blob parameter
            let swiftType = name == blobParamName ? "VIPSBlob" : getSwiftType(param.parameterType)

            // Special handling for parameter labels
            if name == "right" {
                params.append("_ rhs: \(swiftType)")
            } else if name == "in" && isFirstParam {
                params.append("_ `in`: \(swiftType)")
            } else {
                // Remove backticks from function name for comparison
                let cleanFuncName = funcName.replacingOccurrences(of: "`", with: "")
                if isFirstParam && (paramName == cleanFuncName || cleanFuncName.hasSuffix(paramName.prefix(1).uppercased() + paramName.dropFirst())) {
                    params.append("_ \(paramName): \(swiftType)")
                } else {
                    params.append("\(paramName): \(swiftType)")
                }
            }

            isFirstParam = false
        }

        // Add optional parameters
        for name in optionalInput {
            if name == blobParamName {
                continue  // Skip blob parameter as it's already in required params
            }
            guard let param = details.parameters[name] else { continue }
            let paramName = swiftizeParam(name)
            let swiftType = getSwiftType(param.parameterType)
            params.append("\(paramName): \(swiftType)? = nil")
        }

        signature += params.joined(separator: ", ")
        signature += ") throws -> Self {"

        result.append("    @inlinable")
        result.append(signature)

        // Generate function body
        let blobParamSwift = swiftizeParam(blobParamName)
        result.append("        // the operation will retain the blob")
        result.append("        try \(blobParamSwift).withVipsBlob { blob in")
        result.append("            try Self { out in")
        result.append("                var opt = VIPSOption()")
        result.append("")
        result.append("                opt.set(\"\(blobParamName)\", value: blob)")

        // Set other required parameters
        for name in details.methodArgs {
            if name == details.memberX || name == blobParamName {
                continue
            }
            let paramName: String
            if name == "right" {
                paramName = "rhs"
            } else if name == "in" {
                paramName = "`in`"
            } else {
                paramName = swiftizeParam(name)
            }
            result.append("                opt.set(\"\(name)\", value: \(paramName))")
        }

        // Set optional parameters
        for name in optionalInput {
            if name == blobParamName {
                continue
            }
            let paramName = swiftizeParam(name)
            result.append("                if let \(paramName) = \(paramName) {")
            result.append("                    opt.set(\"\(name)\", value: \(paramName))")
            result.append("                }")
        }

        result.append("                opt.set(\"out\", value: &out)")
        result.append("")
        result.append("                try Self.call(\"\(details.nickname)\", options: &opt)")
        result.append("            }")
        result.append("        }")
        result.append("    }")

        return result.joined(separator: "\n")
    }

    // MARK: - Collection<UInt8> Overload

    /// Generate Collection<UInt8> overload for buffer operations
    ///
    /// Creates an overload that accepts any Collection of UInt8 for buffer-based operations.
    ///
    /// - Parameter details: Operation details
    /// - Returns: Swift method string, or nil if not applicable
    func generateCollectionOverload(for details: VIPSOperationDetails) -> String? {
        // Skip deprecated operations
        if details.isDeprecated {
            return nil
        }

        // Find the blob parameter
        guard let blobParamName = findBlobParameter(in: details) else {
            return nil
        }

        // Only generate for load operations that return images
        guard details.nickname.contains("load") else {
            return nil
        }

        let requiredOutput = details.requiredOutput.filter { $0 != details.memberX }
        guard let firstOutput = requiredOutput.first,
              let outputParam = details.parameters[firstOutput],
              outputParam.parameterType == vips_image_get_type() else {
            return nil
        }

        // Filter out deprecated and internal parameters
        let optionalInput = details.optionalInput.filter { name in
            guard let param = details.parameters[name] else { return false }
            return !param.isDeprecated && name != "nickname" && name != "description"
        }

        var result: [String] = []

        // Generate documentation
        result.append("    /// \(details.description.prefix(1).uppercased())\(details.description.dropFirst())")
        result.append("    ///")
        result.append("    /// - Parameters:")
        result.append("    ///   - \(swiftizeParam(blobParamName)): Buffer to load from")

        // Add other parameters documentation
        for name in details.methodArgs + optionalInput {
            if name == blobParamName || name == details.memberX {
                continue
            }
            if let param = details.parameters[name] {
                let paramName = swiftizeParam(name)
                result.append("    ///   - \(paramName): \(param.description)")
            }
        }

        // Build function signature
        var funcName = snakeToCamel(details.nickname)

        // Remove common suffixes for overloaded methods
        let overloadSuffixes = ["Buffer", "Source", "Target", "Mime"]
        for suffix in overloadSuffixes {
            if funcName.hasSuffix(suffix) {
                funcName = String(funcName.dropLast(suffix.count))
                break
            }
        }

        if swiftKeywords.contains(funcName) {
            funcName = "`\(funcName)`"
        }

        var signature = "    public static func \(funcName)("

        // Add required parameters
        var params = ["\(swiftizeParam(blobParamName)): some Collection<UInt8>"]

        // Add other required parameters
        for name in details.methodArgs {
            if name == details.memberX || name == blobParamName {
                continue
            }
            guard let param = details.parameters[name] else { continue }
            let paramName = swiftizeParam(name)
            let swiftType = getSwiftType(param.parameterType)
            params.append("\(paramName): \(swiftType)")
        }

        // Add optional parameters
        for name in optionalInput {
            guard let param = details.parameters[name] else { continue }
            let paramName = swiftizeParam(name)
            let swiftType = getSwiftType(param.parameterType)
            params.append("\(paramName): \(swiftType)? = nil")
        }

        signature += params.joined(separator: ", ")
        signature += ") throws -> Self {"

        result.append("    @inlinable")
        result.append(signature)

        // Generate function body - create VIPSBlob and call the VIPSBlob version
        let blobParamSwift = swiftizeParam(blobParamName)
        result.append("        let blob = VIPSBlob(\(blobParamSwift))")
        result.append("        return try \(funcName)(")
        result.append("            \(blobParamSwift): blob,")

        // Add other required parameters
        for name in details.methodArgs {
            if name == details.memberX || name == blobParamName {
                continue
            }
            let paramName = swiftizeParam(name)
            result.append("            \(paramName): \(paramName),")
        }

        // Add optional parameters
        for name in optionalInput {
            let paramName = swiftizeParam(name)
            result.append("            \(paramName): \(paramName),")
        }

        // Remove trailing comma from last parameter
        if let lastLine = result.last, lastLine.hasSuffix(",") {
            result[result.count - 1] = String(lastLine.dropLast())
        }

        result.append("        )")
        result.append("    }")

        return result.joined(separator: "\n")
    }

    // MARK: - UnsafeRawBufferPointer Overload

    /// Generate UnsafeRawBufferPointer overload for buffer operations
    ///
    /// Creates a zero-copy overload that accepts UnsafeRawBufferPointer.
    /// The caller must ensure the buffer remains valid for the lifetime of the image.
    ///
    /// - Parameter details: Operation details
    /// - Returns: Swift method string, or nil if not applicable
    func generateUnsafeBufferOverload(for details: VIPSOperationDetails) -> String? {
        // Skip deprecated operations
        if details.isDeprecated {
            return nil
        }

        // Find the blob parameter
        guard let blobParamName = findBlobParameter(in: details) else {
            return nil
        }

        // Only generate for load operations that return images
        guard details.nickname.contains("load") else {
            return nil
        }

        let requiredOutput = details.requiredOutput.filter { $0 != details.memberX }
        guard let firstOutput = requiredOutput.first,
              let outputParam = details.parameters[firstOutput],
              outputParam.parameterType == vips_image_get_type() else {
            return nil
        }

        // Filter out deprecated and internal parameters
        let optionalInput = details.optionalInput.filter { name in
            guard let param = details.parameters[name] else { return false }
            return !param.isDeprecated && name != "nickname" && name != "description"
        }

        var result: [String] = []

        // Generate documentation
        result.append("    /// \(details.description.prefix(1).uppercased())\(details.description.dropFirst()) without copying the data. The caller must ensure the buffer remains valid for")
        result.append("    /// the lifetime of the returned image and all its descendants.")
        result.append("    ///")
        result.append("    /// - Parameters:")
        result.append("    ///   - \(swiftizeParam(blobParamName)): Buffer to load from")

        // Add other parameters documentation
        for name in details.methodArgs + optionalInput {
            if name == blobParamName || name == details.memberX {
                continue
            }
            if let param = details.parameters[name] {
                let paramName = swiftizeParam(name)
                result.append("    ///   - \(paramName): \(param.description)")
            }
        }

        // Build function signature
        var funcName = snakeToCamel(details.nickname)

        // Remove common suffixes for overloaded methods
        let overloadSuffixes = ["Buffer", "Source", "Target", "Mime"]
        for suffix in overloadSuffixes {
            if funcName.hasSuffix(suffix) {
                funcName = String(funcName.dropLast(suffix.count))
                break
            }
        }

        if swiftKeywords.contains(funcName) {
            funcName = "`\(funcName)`"
        }

        var signature = "    public static func \(funcName)("

        // Add required parameters
        var params = ["unsafeBuffer \(swiftizeParam(blobParamName)): UnsafeRawBufferPointer"]

        // Add other required parameters
        for name in details.methodArgs {
            if name == details.memberX || name == blobParamName {
                continue
            }
            guard let param = details.parameters[name] else { continue }
            let paramName = swiftizeParam(name)
            let swiftType = getSwiftType(param.parameterType)
            params.append("\(paramName): \(swiftType)")
        }

        // Add optional parameters
        for name in optionalInput {
            guard let param = details.parameters[name] else { continue }
            let paramName = swiftizeParam(name)
            let swiftType = getSwiftType(param.parameterType)
            params.append("\(paramName): \(swiftType)? = nil")
        }

        signature += params.joined(separator: ", ")
        signature += ") throws -> Self {"

        result.append("    @inlinable")
        result.append(signature)

        // Generate function body - create VIPSBlob with noCopy and call the VIPSBlob version
        let blobParamSwift = swiftizeParam(blobParamName)
        result.append("        let blob = VIPSBlob(noCopy: \(blobParamSwift))")
        result.append("        return try \(funcName)(")
        result.append("            \(blobParamSwift): blob,")

        // Add other required parameters
        for name in details.methodArgs {
            if name == details.memberX || name == blobParamName {
                continue
            }
            let paramName = swiftizeParam(name)
            result.append("            \(paramName): \(paramName),")
        }

        // Add optional parameters
        for name in optionalInput {
            let paramName = swiftizeParam(name)
            result.append("            \(paramName): \(paramName),")
        }

        // Remove trailing comma from last parameter
        if let lastLine = result.last, lastLine.hasSuffix(",") {
            result[result.count - 1] = String(lastLine.dropLast())
        }

        result.append("        )")
        result.append("    }")

        return result.joined(separator: "\n")
    }

    // MARK: - Relational Convenience Methods

    /// Generate relational convenience methods (equal, notequal, less, etc.)
    ///
    /// Creates convenience methods for relational and boolean operations.
    ///
    /// - Returns: Swift code string with all relational convenience methods
    func generateRelationalConvenienceMethods() -> String {
        var methods: [String] = []

        // Define relational operations and their corresponding enum values
        let relationalOps: [(String, String, String)] = [
            ("equal", "equal", "Test for equality"),
            ("notequal", "noteq", "Test for inequality"),
            ("less", "less", "Test for less than"),
            ("lesseq", "lesseq", "Test for less than or equal"),
            ("more", "more", "Test for greater than"),
            ("moreeq", "moreeq", "Test for greater than or equal")
        ]

        for (methodName, enumValue, description) in relationalOps {
            // Method with VIPSImage parameter - make first param unnamed for operator compatibility
            methods.append("    /// \(description)")
            methods.append("    ///")
            methods.append("    /// - Parameters:")
            methods.append("    ///   - rhs: Right-hand input image")
            methods.append("    public func \(methodName)(_ rhs: some VIPSImageProtocol) throws -> Self {")
            methods.append("        return try relational(rhs, relational: .\(enumValue))")
            methods.append("    }")
            methods.append("")

            // Method with Double parameter
            methods.append("    /// \(description)")
            methods.append("    ///")
            methods.append("    /// - Parameters:")
            methods.append("    ///   - value: Constant value")
            methods.append("    public func \(methodName)(_ value: Double) throws -> Self {")
            methods.append("        return try relationalConst(relational: .\(enumValue), c: [value])")
            methods.append("    }")
            methods.append("")
        }

        // Add boolean operations for bitwise operators
        let booleanOps: [(String, String, String)] = [
            ("andimage", "and", "Bitwise AND of two images"),
            ("orimage", "or", "Bitwise OR of two images"),
            ("eorimage", "eor", "Bitwise XOR of two images")
        ]

        for (methodName, enumValue, description) in booleanOps {
            methods.append("    /// \(description)")
            methods.append("    ///")
            methods.append("    /// - Parameters:")
            methods.append("    ///   - rhs: Right-hand input image")
            methods.append("    public func \(methodName)(_ rhs: some VIPSImageProtocol) throws -> Self {")
            methods.append("        return try boolean(rhs, boolean: .\(enumValue))")
            methods.append("    }")
            methods.append("")
        }

        // Add shift operations (these use boolean operations)
        let shiftOps: [(String, String, String)] = [
            ("lshift", "lshift", "Left shift"),
            ("rshift", "rshift", "Right shift")
        ]

        for (methodName, enumValue, description) in shiftOps {
            methods.append("    /// \(description)")
            methods.append("    ///")
            methods.append("    /// - Parameters:")
            methods.append("    ///   - amount: Number of bits to shift")
            methods.append("    public func \(methodName)(_ amount: Int) throws -> Self {")
            methods.append("        return try booleanConst(boolean: .\(enumValue), c: [Double(amount)])")
            methods.append("    }")
            methods.append("")
        }

        return methods.joined(separator: "\n")
    }

    // MARK: - Helper Methods

    /// Find the blob parameter in operation details
    private func findBlobParameter(in details: VIPSOperationDetails) -> String? {
        let allInputParams = details.methodArgs + details.optionalInput
        for name in allInputParams {
            if let param = details.parameters[name],
               param.parameterType == shim_VIPS_TYPE_BLOB() {
                return name
            }
        }
        return nil
    }
}
