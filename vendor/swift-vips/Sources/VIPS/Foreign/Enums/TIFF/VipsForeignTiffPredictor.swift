import Cvips
import CvipsShim

extension VipsForeignTiffPredictor {
    public static var none: Self { VIPS_FOREIGN_TIFF_PREDICTOR_NONE }
    public static var horizontal: Self { VIPS_FOREIGN_TIFF_PREDICTOR_HORIZONTAL }
    public static var float: Self { VIPS_FOREIGN_TIFF_PREDICTOR_FLOAT }
    public static var last: Self { VIPS_FOREIGN_TIFF_PREDICTOR_LAST }
}