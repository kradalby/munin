import Cvips
import CvipsShim

public typealias VipsDirection = Cvips.VipsDirection

extension VipsDirection {
    public static var horizontal: Self { VIPS_DIRECTION_HORIZONTAL }
    public static var vertical: Self { VIPS_DIRECTION_VERTICAL }
    public static var last: Self { VIPS_DIRECTION_LAST }
}