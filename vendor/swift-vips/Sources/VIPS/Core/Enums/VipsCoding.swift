import Cvips
import CvipsShim

public typealias VipsCoding = Cvips.VipsCoding

extension VipsCoding {
    public static var error: Self { VIPS_CODING_ERROR }
    public static var none: Self { VIPS_CODING_NONE }
    public static var labq: Self { VIPS_CODING_LABQ }
    public static var rad: Self { VIPS_CODING_RAD }
    public static var last: Self { VIPS_CODING_LAST }
}