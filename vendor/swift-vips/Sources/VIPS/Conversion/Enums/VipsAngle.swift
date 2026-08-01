import Cvips
import CvipsShim

public typealias VipsAngle = Cvips.VipsAngle

extension VipsAngle {
    public static var d0: Self { VIPS_ANGLE_D0 }
    public static var d90: Self { VIPS_ANGLE_D90 }
    public static var d180: Self { VIPS_ANGLE_D180 }
    public static var d270: Self { VIPS_ANGLE_D270 }
    public static var last: Self { VIPS_ANGLE_LAST }
}