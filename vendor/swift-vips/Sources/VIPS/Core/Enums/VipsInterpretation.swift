import Cvips
import CvipsShim

public typealias VipsInterpretation = Cvips.VipsInterpretation

extension VipsInterpretation {
    public static var error: Self { VIPS_INTERPRETATION_ERROR }
    public static var multiband: Self { VIPS_INTERPRETATION_MULTIBAND }
    public static var bw: Self { VIPS_INTERPRETATION_B_W }
    public static var histogram: Self { VIPS_INTERPRETATION_HISTOGRAM }
    public static var xyz: Self { VIPS_INTERPRETATION_XYZ }
    public static var lab: Self { VIPS_INTERPRETATION_LAB }
    public static var cmyk: Self { VIPS_INTERPRETATION_CMYK }
    public static var labq: Self { VIPS_INTERPRETATION_LABQ }
    public static var rgb: Self { VIPS_INTERPRETATION_RGB }
    public static var cmc: Self { VIPS_INTERPRETATION_CMC }
    public static var lch: Self { VIPS_INTERPRETATION_LCH }
    public static var labs: Self { VIPS_INTERPRETATION_LABS }
    public static var srgb: Self { VIPS_INTERPRETATION_sRGB }
    public static var yxy: Self { VIPS_INTERPRETATION_YXY }
    public static var fourier: Self { VIPS_INTERPRETATION_FOURIER }
    public static var rgb16: Self { VIPS_INTERPRETATION_RGB16 }
    public static var grey16: Self { VIPS_INTERPRETATION_GREY16 }
    public static var matrix: Self { VIPS_INTERPRETATION_MATRIX }
    public static var scrgb: Self { VIPS_INTERPRETATION_scRGB }
    public static var hsv: Self { VIPS_INTERPRETATION_HSV }
    public static var last: Self { VIPS_INTERPRETATION_LAST }
}