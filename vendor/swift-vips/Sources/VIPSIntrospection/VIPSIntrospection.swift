//
//  VIPSIntrospection.swift
//  VIPSIntrospection
//
//  Swift API for libvips GObject introspection
//

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif
import Cvips
import CvipsShim
import Foundation

/// Information about a VIPS operation
public struct VIPSOperationInfo {
    public let nickname: String
    public let description: String
    public let operationType: UInt  // GType as UInt
    public let flags: Int32
    public let parameters: [VIPSParameterInfo]

    /// Check if the operation is deprecated
    public var isDeprecated: Bool {
        return (UInt32(flags) & VIPS_OPERATION_DEPRECATED.rawValue) != 0
    }
}

/// Information about a VIPS operation parameter
public struct VIPSParameterInfo {
    public let name: String
    public let description: String
    public let parameterType: UInt  // GType as UInt
    public let flags: Int32
    public let priority: Int32

    /// Check if this parameter is required
    public var isRequired: Bool {
        return (UInt32(flags) & VIPS_ARGUMENT_REQUIRED.rawValue) != 0
    }

    /// Check if this parameter is input
    public var isInput: Bool {
        return (UInt32(flags) & VIPS_ARGUMENT_INPUT.rawValue) != 0
    }

    /// Check if this parameter is output
    public var isOutput: Bool {
        return (UInt32(flags) & VIPS_ARGUMENT_OUTPUT.rawValue) != 0
    }

    /// Check if this parameter is deprecated
    public var isDeprecated: Bool {
        return (UInt32(flags) & VIPS_ARGUMENT_DEPRECATED.rawValue) != 0
    }
}

/// Extended operation details with classified parameters
public struct VIPSOperationDetails {
    public let nickname: String
    public let description: String
    public let flags: Int32
    public let memberX: String?           // The "self" parameter (first required input image)
    public let methodArgs: [String]       // Required inputs (excluding memberX)
    public let optionalInput: [String]    // Optional input parameters
    public let requiredOutput: [String]   // Required output parameters
    public let optionalOutput: [String]   // Optional output parameters
    public let parameters: [String: VIPSParameterInfo]  // All parameters by name

    public var isDeprecated: Bool {
        return (UInt32(flags) & VIPS_OPERATION_DEPRECATED.rawValue) != 0
    }
}

/// Swift wrapper for GType information
public struct VIPSGType {
    public let gtype: UInt

    public init(_ gtype: UInt) {
        self.gtype = gtype
    }

    /// Get the type name
    public var name: String {
        guard let cString = shim_gtype_name(gtype) else { return "" }
        return String(cString: cString)
    }

    /// Get the fundamental type
    public var fundamental: VIPSGType {
        return VIPSGType(shim_gtype_fundamental(gtype))
    }

    /// Check if this is an enum type
    public var isEnum: Bool {
        return shim_gtype_is_enum(gtype) != 0
    }

    /// Check if this is a flags type
    public var isFlags: Bool {
        return shim_gtype_is_flags(gtype) != 0
    }
}

/// Main introspection interface
public class VIPSIntrospection {

    /// Initialize VIPS library for introspection
    public static func initialize() throws {
        // Force English locale for consistent code generation
        setenv("LANG", "C", 1)
        setenv("LC_ALL", "C", 1)

        if vips_init("swift-vips-introspection") != 0 {
            throw VIPSIntrospectionError.initializationFailed
        }
    }

    /// Shutdown VIPS library
    public static func shutdown() {
        vips_shutdown()
    }

    /// Get all available VIPS operations
    public static func getAllOperations() throws -> [String] {
        var count: Int32 = 0
        guard let types = shim_get_all_operation_types(&count) else {
            throw VIPSIntrospectionError.failedToGetOperations
        }
        defer { shim_free_operation_types(types) }

        var nicknames = Set<String>()
        for i in 0..<Int(count) {
            let gtype = types[Int(i)]
            if let cString = vips_nickname_find(gtype) {
                nicknames.insert(String(cString: cString))
            }
        }

        return nicknames.sorted()
    }

    /// Get detailed information about a specific operation
    public static func getOperationInfo(_ nickname: String) throws -> VIPSOperationInfo {
        guard let info = shim_get_operation_info(nickname) else {
            throw VIPSIntrospectionError.operationNotFound(nickname)
        }
        defer { shim_free_operation_info(info) }

        // Get parameters
        var paramCount: Int32 = 0
        guard let params = shim_get_operation_parameters(nickname, &paramCount) else {
            throw VIPSIntrospectionError.failedToGetParameters(nickname)
        }
        defer { shim_free_parameter_info(params) }

        var parameters: [VIPSParameterInfo] = []
        for i in 0..<Int(paramCount) {
            let param = params[Int(i)]
            parameters.append(VIPSParameterInfo(
                name: String(cString: param.name),
                description: String(cString: param.description),
                parameterType: param.parameter_type,
                flags: param.flags,
                priority: param.priority
            ))
        }

        return VIPSOperationInfo(
            nickname: String(cString: info.pointee.nickname),
            description: String(cString: info.pointee.description),
            operationType: info.pointee.operation_type,
            flags: info.pointee.flags,
            parameters: parameters
        )
    }

    /// Get detailed operation information with classified parameters
    public static func getOperationDetails(_ nickname: String) throws -> VIPSOperationDetails {
        // Get basic operation info and parameters
        let info = try getOperationInfo(nickname)

        // Get the VipsImage GType for comparison
        let imageType = vips_image_get_type()

        // Sort parameters by priority (lower priority first)
        let sortedParams = info.parameters.sorted { $0.priority < $1.priority }

        // Create parameter dictionary for quick lookup
        var paramDict: [String: VIPSParameterInfo] = [:]
        for param in info.parameters {
            paramDict[param.name] = param
        }

        // Classify parameters
        var memberX: String? = nil
        var methodArgs: [String] = []
        var optionalInput: [String] = []
        var requiredOutput: [String] = []
        var optionalOutput: [String] = []

        for param in sortedParams {
            // Skip deprecated parameters
            if param.isDeprecated {
                continue
            }

            // Skip internal parameters
            if param.name == "nickname" || param.name == "description" {
                continue
            }

            // Classify based on flags
            // IMPORTANT: Check for outputs FIRST, because "out" parameter has both INPUT and OUTPUT flags
            if param.isOutput && param.isRequired {
                requiredOutput.append(param.name)
            } else if param.isOutput && !param.isRequired {
                optionalOutput.append(param.name)
            } else if param.isRequired && param.isInput {
                // If memberX is nil AND parameter type is VipsImage, this is memberX
                if memberX == nil && param.parameterType == imageType {
                    memberX = param.name
                } else {
                    methodArgs.append(param.name)
                }
            } else if !param.isRequired && param.isInput {
                optionalInput.append(param.name)
            }
        }

        return VIPSOperationDetails(
            nickname: info.nickname,
            description: info.description,
            flags: info.flags,
            memberX: memberX,
            methodArgs: methodArgs,
            optionalInput: optionalInput,
            requiredOutput: requiredOutput,
            optionalOutput: optionalOutput,
            parameters: paramDict
        )
    }

    /// Get type information for a GType
    public static func getTypeInfo(_ gtype: UInt) -> VIPSGType {
        return VIPSGType(gtype)
    }
}

/// Errors that can occur during introspection
public enum VIPSIntrospectionError: Error, CustomStringConvertible {
    case initializationFailed
    case failedToGetOperations
    case operationNotFound(String)
    case failedToGetParameters(String)

    public var description: String {
        switch self {
        case .initializationFailed:
            return "Failed to initialize VIPS library"
        case .failedToGetOperations:
            return "Failed to get operation list"
        case .operationNotFound(let nickname):
            return "Operation '\(nickname)' not found"
        case .failedToGetParameters(let nickname):
            return "Failed to get parameters for operation '\(nickname)'"
        }
    }
}
