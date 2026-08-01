import Cvips
import CvipsShim

public typealias VipsAlign = Cvips.VipsAlign

extension VipsAlign {
    public static var low: Self { VIPS_ALIGN_LOW }
    public static var centre: Self { VIPS_ALIGN_CENTRE }
    public static var high: Self { VIPS_ALIGN_HIGH }
    public static var last: Self { VIPS_ALIGN_LAST }
}