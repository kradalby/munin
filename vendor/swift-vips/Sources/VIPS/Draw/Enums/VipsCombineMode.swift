import Cvips
import CvipsShim

public typealias VipsCombineMode = Cvips.VipsCombineMode

extension VipsCombineMode {
    public static var set: Self { VIPS_COMBINE_MODE_SET }
    public static var add: Self { VIPS_COMBINE_MODE_ADD }
    public static var last: Self { VIPS_COMBINE_MODE_LAST }
}