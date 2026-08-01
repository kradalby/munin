import Cvips
import CvipsShim

public typealias VipsArgumentFlags = Cvips.VipsArgumentFlags

extension VipsArgumentFlags {
    public static var none: Self { VIPS_ARGUMENT_NONE }
    public static var required: Self { VIPS_ARGUMENT_REQUIRED }
    public static var construct: Self { VIPS_ARGUMENT_CONSTRUCT }
    public static var setOnce: Self { VIPS_ARGUMENT_SET_ONCE }
    public static var setAlways: Self { VIPS_ARGUMENT_SET_ALWAYS }
    public static var input: Self { VIPS_ARGUMENT_INPUT }
    public static var output: Self { VIPS_ARGUMENT_OUTPUT }
    public static var deprecated: Self { VIPS_ARGUMENT_DEPRECATED }
    public static var modify: Self { VIPS_ARGUMENT_MODIFY }
    public static var nonHashable: Self { VIPS_ARGUMENT_NON_HASHABLE }
}