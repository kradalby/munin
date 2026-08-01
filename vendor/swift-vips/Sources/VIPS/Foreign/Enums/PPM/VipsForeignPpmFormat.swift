import Cvips
import CvipsShim

extension VipsForeignPpmFormat {
    public static var pbm: Self { VIPS_FOREIGN_PPM_FORMAT_PBM }
    public static var pgm: Self { VIPS_FOREIGN_PPM_FORMAT_PGM }
    public static var ppm: Self { VIPS_FOREIGN_PPM_FORMAT_PPM }
    public static var pfm: Self { VIPS_FOREIGN_PPM_FORMAT_PFM }
    public static var pnm: Self { VIPS_FOREIGN_PPM_FORMAT_PNM }
    public static var last: Self { VIPS_FOREIGN_PPM_FORMAT_LAST }
}