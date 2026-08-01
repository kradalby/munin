import Cvips
import CvipsShim

public typealias VipsForeignKeep = Cvips.VipsForeignKeep

extension VipsForeignKeep {
    public static var none: Self { VIPS_FOREIGN_KEEP_NONE }
    public static var exif: Self { VIPS_FOREIGN_KEEP_EXIF }
    public static var xmp: Self { VIPS_FOREIGN_KEEP_XMP }
    public static var iptc: Self { VIPS_FOREIGN_KEEP_IPTC }
    public static var icc: Self { VIPS_FOREIGN_KEEP_ICC }
    public static var other: Self { VIPS_FOREIGN_KEEP_OTHER }
    public static var all: Self { VIPS_FOREIGN_KEEP_ALL }
}