import Cvips
import CvipsShim

public typealias VipsDemandStyle = Cvips.VipsDemandStyle

extension VipsDemandStyle {
    public static var error: Self { VIPS_DEMAND_STYLE_ERROR }
    public static var smalltile: Self { VIPS_DEMAND_STYLE_SMALLTILE }
    public static var fatstrip: Self { VIPS_DEMAND_STYLE_FATSTRIP }
    public static var thinstrip: Self { VIPS_DEMAND_STYLE_THINSTRIP }
    public static var any: Self { VIPS_DEMAND_STYLE_ANY }
}