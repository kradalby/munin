import Cvips
import CvipsShim

public typealias VipsPrecision = Cvips.VipsPrecision

extension VipsPrecision {
    public static var integer: Self { VIPS_PRECISION_INTEGER }
    public static var float: Self { VIPS_PRECISION_FLOAT }
    public static var approximate: Self { VIPS_PRECISION_APPROXIMATE }
    public static var last: Self { VIPS_PRECISION_LAST }
}