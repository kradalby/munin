import Cvips
import CvipsShim

extension VipsForeignDzContainer {
    public static var fs: Self { VIPS_FOREIGN_DZ_CONTAINER_FS }
    public static var zip: Self { VIPS_FOREIGN_DZ_CONTAINER_ZIP }
    public static var szi: Self { VIPS_FOREIGN_DZ_CONTAINER_SZI }
    public static var last: Self { VIPS_FOREIGN_DZ_CONTAINER_LAST }
}