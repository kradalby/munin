//
//  TypeMapping.swift
//  VIPSGenerator
//
//  GType to Swift type mapping for code generation
//

import Cvips
import CvipsShim

/// Maps a GType to its corresponding Swift type name
/// - Parameter gtype: The GType value to map
/// - Returns: Swift type name as a string
func getSwiftType(_ gtype: UInt) -> String {
    // Direct type mappings
    if gtype == shim_g_type_boolean() {
        return "Bool"
    } else if gtype == shim_G_TYPE_INT() {
        return "Int"
    } else if gtype == shim_G_TYPE_DOUBLE() {
        return "Double"
    } else if gtype == shim_G_TYPE_STRING() {
        return "String"
    } else if gtype == vips_ref_string_get_type() {
        return "String"
    } else if gtype == vips_image_get_type() {
        return "some VIPSImageProtocol"
    } else if gtype == vips_source_get_type() {
        return "VIPSSource"
    } else if gtype == vips_target_get_type() {
        return "VIPSTarget"
    } else if gtype == g_type_from_name("guint64") {
        return "UInt64"
    } else if gtype == vips_interpolate_get_type() {
        return "VIPSInterpolate"
    } else if gtype == shim_VIPS_TYPE_ARRAY_INT() {
        return "[Int]"
    } else if gtype == shim_VIPS_TYPE_ARRAY_DOUBLE() {
        return "[Double]"
    } else if gtype == vips_array_image_get_type() {
        return "[VIPSImage]"
    } else if gtype == shim_VIPS_TYPE_BLOB() {
        return "VIPSBlob"
    }

    // Check for enum types
    if shim_gtype_is_enum(gtype) != 0 {
        if let typeName = shim_gtype_name(gtype) {
            return String(cString: typeName)
        }
    }

    // Check for flags types
    if shim_gtype_is_flags(gtype) != 0 {
        if let typeName = shim_gtype_name(gtype) {
            return String(cString: typeName)
        }
    }

    // Unknown type
    return "Any"
}
