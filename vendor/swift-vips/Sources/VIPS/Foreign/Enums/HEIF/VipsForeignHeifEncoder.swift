import Cvips
import CvipsShim

extension VipsForeignHeifEncoder {
    public static var auto: Self { VIPS_FOREIGN_HEIF_ENCODER_AUTO }
    public static var aom: Self { VIPS_FOREIGN_HEIF_ENCODER_AOM }
    public static var rav1e: Self { VIPS_FOREIGN_HEIF_ENCODER_RAV1E }
    public static var svt: Self { VIPS_FOREIGN_HEIF_ENCODER_SVT }
    public static var x265: Self { VIPS_FOREIGN_HEIF_ENCODER_X265 }
    public static var last: Self { VIPS_FOREIGN_HEIF_ENCODER_LAST }
}