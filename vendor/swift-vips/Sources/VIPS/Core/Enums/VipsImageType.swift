import Cvips
import CvipsShim

public typealias VipsImageType = Cvips.VipsImageType

extension VipsImageType {
    public static var error: Self { VIPS_IMAGE_ERROR }
    public static var none: Self { VIPS_IMAGE_NONE }
    public static var setbuf: Self { VIPS_IMAGE_SETBUF }
    public static var setbufForeign: Self { VIPS_IMAGE_SETBUF_FOREIGN }
    public static var openin: Self { VIPS_IMAGE_OPENIN }
    public static var mmapin: Self { VIPS_IMAGE_MMAPIN }
    public static var mmapinrw: Self { VIPS_IMAGE_MMAPINRW }
    public static var openout: Self { VIPS_IMAGE_OPENOUT }
    public static var partial: Self { VIPS_IMAGE_PARTIAL }
}