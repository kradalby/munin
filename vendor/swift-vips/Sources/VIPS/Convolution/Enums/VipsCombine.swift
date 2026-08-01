import Cvips
import CvipsShim

public typealias VipsCombine = Cvips.VipsCombine

extension VipsCombine {
    public static var max: Self { VIPS_COMBINE_MAX }
    public static var sum: Self { VIPS_COMBINE_SUM }
    public static var min: Self { VIPS_COMBINE_MIN }
    public static var last: Self { VIPS_COMBINE_LAST }
}