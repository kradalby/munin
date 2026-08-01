import Cvips
import CvipsShim

public typealias VipsForeignSubsample = Cvips.VipsForeignSubsample

extension VipsForeignSubsample {
    public static var auto: Self { VIPS_FOREIGN_SUBSAMPLE_AUTO }
    public static var on: Self { VIPS_FOREIGN_SUBSAMPLE_ON }
    public static var off: Self { VIPS_FOREIGN_SUBSAMPLE_OFF }
    public static var last: Self { VIPS_FOREIGN_SUBSAMPLE_LAST }
}