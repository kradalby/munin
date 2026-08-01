import Cvips
import CvipsShim

public typealias VipsOperationBoolean = Cvips.VipsOperationBoolean

extension VipsOperationBoolean {
    public static var and: Self { VIPS_OPERATION_BOOLEAN_AND }
    public static var or: Self { VIPS_OPERATION_BOOLEAN_OR }
    public static var eor: Self { VIPS_OPERATION_BOOLEAN_EOR }
    public static var lshift: Self { VIPS_OPERATION_BOOLEAN_LSHIFT }
    public static var rshift: Self { VIPS_OPERATION_BOOLEAN_RSHIFT }
    public static var last: Self { VIPS_OPERATION_BOOLEAN_LAST }
}