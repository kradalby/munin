//
//  CodeGenerator.swift
//  VIPSGenerator
//
//  Swift code generator for VIPS operations
//

import Cvips
import CvipsShim
import Foundation
import VIPSIntrospection

/// Code generator for VIPS operation wrappers
struct CodeGenerator {

    // MARK: - Skip Conditions

    /// Check if this operation should be skipped
    /// - Parameter details: The operation details to check
    /// - Returns: true if the operation should be skipped
    func shouldSkip(_ details: VIPSOperationDetails) -> Bool {
        // Skip deprecated operations
        if details.isDeprecated {
            return true
        }

        // Skip operations without outputs (unless it's a save operation or operations like avg/min/max)
        if details.requiredOutput.isEmpty {
            // Allow save operations even without outputs
            if details.nickname.contains("save") {
                return false
            }
            // Otherwise skip
            return true
        }

        // Skip operations ending in _const (they are handled by overloads)
        // EXCEPT we actually need to generate the _const operations themselves
        // The skip happens at a different level (not here)

        return false
    }

    // MARK: - Main Generation

    /// Generate the main wrapper method for an operation
    /// - Parameter details: The operation details
    /// - Returns: Generated Swift code, or nil if should be skipped
    func generateWrapper(for details: VIPSOperationDetails) -> String? {
        // Check if we should skip this operation
        if shouldSkip(details) {
            return nil
        }

        // Get the first required output (if any)
        let firstOutput = details.requiredOutput.first
        let hasImageOutput = firstOutput.flatMap { details.parameters[$0] }.map { param in
            param.parameterType == vips_image_get_type()
        } ?? false

        var lines: [String] = []

        // Generate documentation
        lines.append(contentsOf: generateDocumentation(for: details))

        // Generate method signature
        let signature = generateSignature(for: details, hasImageOutput: hasImageOutput)
        lines.append(signature)

        // Generate method body
        lines.append(contentsOf: generateBody(for: details, hasImageOutput: hasImageOutput))

        return lines.joined(separator: "\n")
    }

    // MARK: - Documentation Generation

    /// Generate Swift doc comments for an operation
    private func generateDocumentation(for details: VIPSOperationDetails) -> [String] {
        var lines: [String] = []

        // Capitalize the first letter of description
        let description = details.description.prefix(1).uppercased() + details.description.dropFirst()
        lines.append("    /// \(description)")

        // Add parameter documentation if there are any parameters
        let allParams = details.methodArgs + details.optionalInput
        if !allParams.isEmpty {
            lines.append("    ///")
            lines.append("    /// - Parameters:")
            for paramName in allParams {
                if let param = details.parameters[paramName] {
                    let swiftName = swiftizeParam(paramName)
                    lines.append("    ///   - \(swiftName): \(param.description)")
                }
            }
        }

        return lines
    }

    // MARK: - Signature Generation

    /// Generate the method signature
    private func generateSignature(for details: VIPSOperationDetails, hasImageOutput: Bool) -> String {
        // Determine if this is a static or instance method
        let isInstanceMethod = details.memberX != nil
        let isLoadOperation = details.nickname.contains("load")

        // Build function name
        var funcName = snakeToCamel(details.nickname)

        // Remove common suffixes for overloaded methods
        let overloadSuffixes = ["Buffer", "Source", "Target"]
        for suffix in overloadSuffixes {
            if funcName.hasSuffix(suffix) {
                funcName = String(funcName.dropLast(suffix.count))
                break
            }
        }

        // Escape function name if it's a Swift keyword
        if swiftKeywords.contains(funcName) {
            funcName = "`\(funcName)`"
        }

        // Determine method type
        let methodType: String
        if isLoadOperation {
            methodType = "public static func"
        } else if isInstanceMethod {
            methodType = "public func"
        } else {
            methodType = "public static func"
        }

        // Build parameters
        var params: [String] = []
        var isFirstParam = true

        // Add required parameters (excluding memberX)
        for paramName in details.methodArgs {
            guard let param = details.parameters[paramName] else { continue }

            let swiftParamName = swiftizeParam(paramName)
            let swiftType = getSwiftType(param.parameterType)

            // Special handling for "right" parameter - rename to "rhs" with _ label
            if paramName == "right" {
                params.append("_ rhs: \(swiftType)")
            }
            // Special handling for "in" parameter when it's the first parameter - hide label
            else if paramName == "in" && isFirstParam {
                params.append("_ `in`: \(swiftType)")
            }
            // Check if first parameter name matches function name (omit label if so)
            else if isFirstParam {
                let cleanFuncName = funcName.trimmingCharacters(in: CharacterSet(charactersIn: "`"))
                if swiftParamName == cleanFuncName || cleanFuncName.hasSuffix(swiftParamName.prefix(1).uppercased() + swiftParamName.dropFirst()) {
                    params.append("_ \(swiftParamName): \(swiftType)")
                } else {
                    params.append("\(swiftParamName): \(swiftType)")
                }
            } else {
                params.append("\(swiftParamName): \(swiftType)")
            }

            isFirstParam = false
        }

        // Add optional parameters
        for paramName in details.optionalInput {
            guard let param = details.parameters[paramName] else { continue }

            let swiftParamName = swiftizeParam(paramName)
            let swiftType = getSwiftType(param.parameterType)
            params.append("\(swiftParamName): \(swiftType)? = nil")
        }

        // Build return type
        var signature = "    \(methodType) \(funcName)(\(params.joined(separator: ", "))) throws"

        // Add return type
        if hasImageOutput {
            signature += " -> Self"
        } else if let firstOutput = details.requiredOutput.first,
                  let outputParam = details.parameters[firstOutput] {
            // Handle other output types
            if outputParam.parameterType == shim_VIPS_TYPE_BLOB() {
                signature += " -> VIPSBlob"
            } else {
                let outputType = getSwiftType(outputParam.parameterType)
                signature += " -> \(outputType)"
            }
        } else if details.nickname.contains("save") {
            // Save operations don't return anything
        }

        signature += " {"

        return signature
    }

    // MARK: - Body Generation

    /// Generate the method body
    private func generateBody(for details: VIPSOperationDetails, hasImageOutput: Bool) -> [String] {
        var lines: [String] = []

        // Check if we have blob parameters
        let hasBlobParams = (details.methodArgs + details.optionalInput).contains { paramName in
            details.parameters[paramName]?.parameterType == shim_VIPS_TYPE_BLOB()
        }

        let firstOutput = details.requiredOutput.first
        let isInstanceMethod = details.memberX != nil

        if hasImageOutput {
            // Image output operations
            if hasBlobParams {
                // Find the blob parameter
                if let blobParam = (details.methodArgs + details.optionalInput).first(where: { paramName in
                    details.parameters[paramName]?.parameterType == shim_VIPS_TYPE_BLOB()
                }) {
                    let blobSwiftName = swiftizeParam(blobParam)
                    lines.append("        // the operation will retain the blob")
                    lines.append("        try \(blobSwiftName).withVipsBlob { blob in")
                    lines.append("            try Self { out in")
                    lines.append("                var opt = VIPSOption()")
                    lines.append("")

                    // Set parameters with blob handling
                    lines.append(contentsOf: generateParameterSetting(
                        for: details,
                        indent: "                ",
                        blobParamName: blobParam
                    ))

                    lines.append("                opt.set(\"out\", value: &out)")
                    lines.append("")
                    lines.append("                try Self.call(\"\(details.nickname)\", options: &opt)")
                    lines.append("            }")
                    lines.append("        }")
                }
            } else {
                // No blob parameters
                lines.append("        return try Self { out in")
                lines.append("            var opt = VIPSOption()")
                lines.append("")

                // Set parameters
                lines.append(contentsOf: generateParameterSetting(
                    for: details,
                    indent: "            ",
                    blobParamName: nil
                ))

                lines.append("            opt.set(\"out\", value: &out)")
                lines.append("")
                lines.append("            try Self.call(\"\(details.nickname)\", options: &opt)")
                lines.append("        }")
            }
        } else if let firstOutput = firstOutput,
                  let outputParam = details.parameters[firstOutput] {
            // Non-image outputs (Double, [Double], VIPSBlob, etc.)
            lines.append("        var opt = VIPSOption()")
            lines.append("")

            // Initialize output variable
            let outputType = getSwiftType(outputParam.parameterType)
            if outputParam.parameterType == shim_VIPS_TYPE_BLOB() {
                lines.append("        let out: UnsafeMutablePointer<UnsafeMutablePointer<VipsBlob>?> = .allocate(capacity: 1)")
                lines.append("        out.initialize(to: nil)")
                lines.append("        defer {")
                lines.append("            out.deallocate()")
                lines.append("        }")
            } else if outputType == "Double" {
                lines.append("        var out: Double = 0.0")
            } else if outputType == "Int" {
                lines.append("        var out: Int = 0")
            } else if outputType == "Bool" {
                lines.append("        var out: Bool = false")
            } else if outputType == "String" {
                lines.append("        var out: String = \"\"")
            } else if outputType == "[Double]" {
                lines.append("        var out: UnsafeMutablePointer<VipsArrayDouble>! = .allocate(capacity: 1)")
            } else if outputType == "[Int]" {
                lines.append("        var out: [Int] = []")
            } else {
                lines.append("        var out: \(outputType) = /* TODO: initialize \(outputType) */")
            }
            lines.append("")

            // Set parameters - use self.image for instance methods with non-image outputs
            lines.append(contentsOf: generateParameterSetting(
                for: details,
                indent: "        ",
                blobParamName: nil,
                useImageProperty: isInstanceMethod
            ))

            // Set output parameter
            let vipsOutputName = normalizeVipsParamName(firstOutput)
            if outputParam.parameterType == shim_VIPS_TYPE_BLOB() {
                lines.append("        opt.set(\"\(vipsOutputName)\", value: out)")
            } else {
                lines.append("        opt.set(\"\(vipsOutputName)\", value: &out)")
            }

            lines.append("")
            lines.append("        try Self.call(\"\(details.nickname)\", options: &opt)")
            lines.append("")

            // Return the output
            if outputParam.parameterType == shim_VIPS_TYPE_BLOB() {
                lines.append("        guard let vipsBlob = out.pointee else {")
                lines.append("            throw VIPSError(\"Failed to get buffer from \(details.nickname)\")")
                lines.append("        }")
                lines.append("")
                lines.append("        return VIPSBlob(vipsBlob)")
            } else if outputType == "[Double]" {
                lines.append("        guard let out else {")
                lines.append("            throw VIPSError(\"\(details.nickname): no output\")")
                lines.append("        }")
                lines.append("")
                lines.append("        defer {")
                lines.append("            vips_area_unref(shim_vips_area(out))")
                lines.append("        }")
                lines.append("        ")
                lines.append("        var length = Int32(0)")
                lines.append("        let doubles = vips_array_double_get(out, &length)")
                lines.append("        let buffer = UnsafeBufferPointer(start: doubles, count: Int(length))")
                lines.append("        return Array(buffer)")
            } else {
                lines.append("        return out")
            }
        } else if details.nickname.contains("save") && isInstanceMethod {
            // Save operations that don't return anything
            lines.append("        var opt = VIPSOption()")
            lines.append("")

            // Set parameters
            lines.append(contentsOf: generateParameterSetting(
                for: details,
                indent: "        ",
                blobParamName: nil
            ))

            lines.append("")
            lines.append("        try Self.call(\"\(details.nickname)\", options: &opt)")
        } else {
            // Other operations without outputs
            lines.append("        var opt = VIPSOption()")
            lines.append("")

            // Set parameters
            lines.append(contentsOf: generateParameterSetting(
                for: details,
                indent: "        ",
                blobParamName: nil
            ))

            lines.append("")
            lines.append("        try Self.call(\"\(details.nickname)\", options: &opt)")
        }

        lines.append("    }")

        return lines
    }

    // MARK: - Parameter Setting

    /// Normalize parameter name for VIPS C API
    /// GObject introspection may return hyphens, but VIPS uses underscores internally
    private func normalizeVipsParamName(_ name: String) -> String {
        return name.replacingOccurrences(of: "-", with: "_")
    }

    /// Generate code to set operation parameters
    private func generateParameterSetting(
        for details: VIPSOperationDetails,
        indent: String,
        blobParamName: String?,
        useImageProperty: Bool = false
    ) -> [String] {
        var lines: [String] = []

        // Set the input image if this is an instance method
        if let memberX = details.memberX {
            let vipsParamName = normalizeVipsParamName(memberX)
            if useImageProperty {
                lines.append("\(indent)opt.set(\"\(vipsParamName)\", value: self.image)")
            } else {
                lines.append("\(indent)opt.set(\"\(vipsParamName)\", value: self)")
            }
        }

        // Set required parameters
        for paramName in details.methodArgs {
            let vipsParamName = normalizeVipsParamName(paramName)
            let swiftParamName: String
            if paramName == "right" {
                swiftParamName = "rhs"
            } else if paramName == "in" {
                swiftParamName = "`in`"
            } else {
                swiftParamName = swiftizeParam(paramName)
            }

            // Special handling for blob parameters
            if paramName == blobParamName {
                lines.append("\(indent)opt.set(\"\(vipsParamName)\", value: blob)")
            } else {
                lines.append("\(indent)opt.set(\"\(vipsParamName)\", value: \(swiftParamName))")
            }
        }

        // Set optional parameters
        for paramName in details.optionalInput {
            let vipsParamName = normalizeVipsParamName(paramName)
            let swiftParamName = swiftizeParam(paramName)

            // Special handling for blob parameters
            if paramName == blobParamName {
                lines.append("\(indent)if let \(swiftParamName) = \(swiftParamName) {")
                lines.append("\(indent)    opt.set(\"\(vipsParamName)\", value: blob)")
                lines.append("\(indent)}")
            } else {
                lines.append("\(indent)if let \(swiftParamName) = \(swiftParamName) {")
                lines.append("\(indent)    opt.set(\"\(vipsParamName)\", value: \(swiftParamName))")
                lines.append("\(indent)}")
            }
        }

        return lines
    }
}
