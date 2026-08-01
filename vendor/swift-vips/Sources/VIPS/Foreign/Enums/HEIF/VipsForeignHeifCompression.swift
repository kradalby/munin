import Cvips
import CvipsShim

extension VipsForeignHeifCompression {
    public static var hevc: Self { VIPS_FOREIGN_HEIF_COMPRESSION_HEVC }
    public static var avc: Self { VIPS_FOREIGN_HEIF_COMPRESSION_AVC }
    public static var jpeg: Self { VIPS_FOREIGN_HEIF_COMPRESSION_JPEG }
    public static var av1: Self { VIPS_FOREIGN_HEIF_COMPRESSION_AV1 }
    public static var last: Self { VIPS_FOREIGN_HEIF_COMPRESSION_LAST }
}