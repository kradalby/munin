import Cvips
import CvipsShim

public typealias VipsInteresting = Cvips.VipsInteresting

extension VipsInteresting {
    public static var none: Self { VIPS_INTERESTING_NONE }
    public static var centre: Self { VIPS_INTERESTING_CENTRE }
    public static var entropy: Self { VIPS_INTERESTING_ENTROPY }
    public static var attention: Self { VIPS_INTERESTING_ATTENTION }
    public static var low: Self { VIPS_INTERESTING_LOW }
    public static var high: Self { VIPS_INTERESTING_HIGH }
    public static var all: Self { VIPS_INTERESTING_ALL }
    public static var last: Self { VIPS_INTERESTING_LAST }
}