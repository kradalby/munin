//
//  OperationAnalysis.swift
//  VIPSGenerator
//
//  Helper functions for analyzing VIPS operations
//

import VIPSIntrospection
import Cvips
import CvipsShim

/// Check if operation has any blob input parameters
/// - Parameter opInfo: The operation information
/// - Returns: true if any input parameter has VIPS_TYPE_BLOB type
func hasBufferParameter(_ opInfo: VIPSOperationInfo) -> Bool {
    // Check all parameters that are input parameters
    for param in opInfo.parameters {
        if param.isInput {
            // Check if the parameter type is VIPS_TYPE_BLOB
            if param.parameterType == shim_VIPS_TYPE_BLOB() {
                return true
            }
        }
    }
    return false
}
