import Cvips
import CvipsShim

public typealias VipsExtend = Cvips.VipsExtend

extension VipsExtend {
    public static var black: Self { VIPS_EXTEND_BLACK }
    public static var copy: Self { VIPS_EXTEND_COPY }
    public static var `repeat`: Self { VIPS_EXTEND_REPEAT }
    public static var mirror: Self { VIPS_EXTEND_MIRROR }
    public static var white: Self { VIPS_EXTEND_WHITE }
    public static var background: Self { VIPS_EXTEND_BACKGROUND }
    public static var last: Self { VIPS_EXTEND_LAST }
}