import Cvips
import CvipsShim

extension VipsForeignPngFilter {
    public static var none: Self { VIPS_FOREIGN_PNG_FILTER_NONE }
    public static var sub: Self { VIPS_FOREIGN_PNG_FILTER_SUB }
    public static var up: Self { VIPS_FOREIGN_PNG_FILTER_UP }
    public static var avg: Self { VIPS_FOREIGN_PNG_FILTER_AVG }
    public static var paeth: Self { VIPS_FOREIGN_PNG_FILTER_PAETH }
    public static var all: Self { VIPS_FOREIGN_PNG_FILTER_ALL }
}