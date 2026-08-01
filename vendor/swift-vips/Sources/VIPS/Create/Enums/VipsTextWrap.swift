import Cvips
import CvipsShim

public typealias VipsTextWrap = Cvips.VipsTextWrap

extension VipsTextWrap {
    public static var word: Self { VIPS_TEXT_WRAP_WORD }
    public static var char: Self { VIPS_TEXT_WRAP_CHAR }
    public static var wordChar: Self { VIPS_TEXT_WRAP_WORD_CHAR }
    public static var none: Self { VIPS_TEXT_WRAP_NONE }
    public static var last: Self { VIPS_TEXT_WRAP_LAST }
}