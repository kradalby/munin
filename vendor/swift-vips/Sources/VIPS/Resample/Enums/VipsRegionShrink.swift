import Cvips
import CvipsShim

public typealias VipsRegionShrink = Cvips.VipsRegionShrink

extension VipsRegionShrink {
    public static var mean: Self { VIPS_REGION_SHRINK_MEAN }
    public static var median: Self { VIPS_REGION_SHRINK_MEDIAN }
    public static var mode: Self { VIPS_REGION_SHRINK_MODE }
    public static var max: Self { VIPS_REGION_SHRINK_MAX }
    public static var min: Self { VIPS_REGION_SHRINK_MIN }
    public static var nearest: Self { VIPS_REGION_SHRINK_NEAREST }
    public static var last: Self { VIPS_REGION_SHRINK_LAST }
}