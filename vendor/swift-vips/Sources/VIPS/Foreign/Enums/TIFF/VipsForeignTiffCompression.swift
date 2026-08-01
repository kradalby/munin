import Cvips
import CvipsShim

extension VipsForeignTiffCompression {
    public static var none: Self { VIPS_FOREIGN_TIFF_COMPRESSION_NONE }
    public static var jpeg: Self { VIPS_FOREIGN_TIFF_COMPRESSION_JPEG }
    public static var deflate: Self { VIPS_FOREIGN_TIFF_COMPRESSION_DEFLATE }
    public static var packbits: Self { VIPS_FOREIGN_TIFF_COMPRESSION_PACKBITS }
    public static var ccittfax4: Self { VIPS_FOREIGN_TIFF_COMPRESSION_CCITTFAX4 }
    public static var lzw: Self { VIPS_FOREIGN_TIFF_COMPRESSION_LZW }
    public static var webp: Self { VIPS_FOREIGN_TIFF_COMPRESSION_WEBP }
    public static var zstd: Self { VIPS_FOREIGN_TIFF_COMPRESSION_ZSTD }
    public static var jp2k: Self { VIPS_FOREIGN_TIFF_COMPRESSION_JP2K }
    public static var last: Self { VIPS_FOREIGN_TIFF_COMPRESSION_LAST }
}