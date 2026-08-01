import Cvips
import CvipsShim

public typealias VipsOperationMath2 = Cvips.VipsOperationMath2

extension VipsOperationMath2 {
    public static var pow: Self { VIPS_OPERATION_MATH2_POW }
    public static var wop: Self { VIPS_OPERATION_MATH2_WOP }
    public static var atan2: Self { VIPS_OPERATION_MATH2_ATAN2 }
    public static var last: Self { VIPS_OPERATION_MATH2_LAST }
}