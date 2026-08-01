import Cvips
import CvipsShim

public typealias VipsOperationMath = Cvips.VipsOperationMath

extension VipsOperationMath {
    public static var sin: Self { VIPS_OPERATION_MATH_SIN }
    public static var cos: Self { VIPS_OPERATION_MATH_COS }
    public static var tan: Self { VIPS_OPERATION_MATH_TAN }
    public static var asin: Self { VIPS_OPERATION_MATH_ASIN }
    public static var acos: Self { VIPS_OPERATION_MATH_ACOS }
    public static var atan: Self { VIPS_OPERATION_MATH_ATAN }
    public static var log: Self { VIPS_OPERATION_MATH_LOG }
    public static var log10: Self { VIPS_OPERATION_MATH_LOG10 }
    public static var exp: Self { VIPS_OPERATION_MATH_EXP }
    public static var exp10: Self { VIPS_OPERATION_MATH_EXP10 }
    public static var sinh: Self { VIPS_OPERATION_MATH_SINH }
    public static var cosh: Self { VIPS_OPERATION_MATH_COSH }
    public static var tanh: Self { VIPS_OPERATION_MATH_TANH }
    public static var asinh: Self { VIPS_OPERATION_MATH_ASINH }
    public static var acosh: Self { VIPS_OPERATION_MATH_ACOSH }
    public static var atanh: Self { VIPS_OPERATION_MATH_ATANH }
    public static var last: Self { VIPS_OPERATION_MATH_LAST }
}