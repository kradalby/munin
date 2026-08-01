import Cvips
import CvipsShim

public typealias VipsFailOn = Cvips.VipsFailOn

extension VipsFailOn {
    public static var none: Self { VIPS_FAIL_ON_NONE }
    public static var truncated: Self { VIPS_FAIL_ON_TRUNCATED }
    public static var error: Self { VIPS_FAIL_ON_ERROR }
    public static var warning: Self { VIPS_FAIL_ON_WARNING }
    public static var last: Self { VIPS_FAIL_ON_LAST }
}