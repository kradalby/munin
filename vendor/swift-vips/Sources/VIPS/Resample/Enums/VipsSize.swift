import Cvips
import CvipsShim

public typealias VipsSize = Cvips.VipsSize

extension VipsSize {
    public static var both: Self { VIPS_SIZE_BOTH }
    public static var up: Self { VIPS_SIZE_UP }
    public static var down: Self { VIPS_SIZE_DOWN }
    public static var force: Self { VIPS_SIZE_FORCE }
    public static var last: Self { VIPS_SIZE_LAST }
}