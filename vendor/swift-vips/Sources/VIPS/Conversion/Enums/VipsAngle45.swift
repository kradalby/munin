import Cvips
import CvipsShim

public typealias VipsAngle45 = Cvips.VipsAngle45

extension VipsAngle45 {
    public static var d0: Self { VIPS_ANGLE45_D0 }
    public static var d45: Self { VIPS_ANGLE45_D45 }
    public static var d90: Self { VIPS_ANGLE45_D90 }
    public static var d135: Self { VIPS_ANGLE45_D135 }
    public static var d180: Self { VIPS_ANGLE45_D180 }
    public static var d225: Self { VIPS_ANGLE45_D225 }
    public static var d270: Self { VIPS_ANGLE45_D270 }
    public static var d315: Self { VIPS_ANGLE45_D315 }
    public static var last: Self { VIPS_ANGLE45_LAST }
}