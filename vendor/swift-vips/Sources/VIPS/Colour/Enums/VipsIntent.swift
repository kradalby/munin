import Cvips
import CvipsShim

public typealias VipsIntent = Cvips.VipsIntent

extension VipsIntent {
    public static var perceptual: Self { VIPS_INTENT_PERCEPTUAL }
    public static var relative: Self { VIPS_INTENT_RELATIVE }
    public static var saturation: Self { VIPS_INTENT_SATURATION }
    public static var absolute: Self { VIPS_INTENT_ABSOLUTE }
    public static var last: Self { VIPS_INTENT_LAST }
}