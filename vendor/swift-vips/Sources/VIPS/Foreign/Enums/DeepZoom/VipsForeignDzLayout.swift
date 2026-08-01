import Cvips
import CvipsShim

extension VipsForeignDzLayout {
    public static var dz: Self { VIPS_FOREIGN_DZ_LAYOUT_DZ }
    public static var zoomify: Self { VIPS_FOREIGN_DZ_LAYOUT_ZOOMIFY }
    public static var google: Self { VIPS_FOREIGN_DZ_LAYOUT_GOOGLE }
    public static var iiif: Self { VIPS_FOREIGN_DZ_LAYOUT_IIIF }
    public static var iiif3: Self { VIPS_FOREIGN_DZ_LAYOUT_IIIF3 }
    public static var last: Self { VIPS_FOREIGN_DZ_LAYOUT_LAST }
}