import Cvips
import CvipsShim

public typealias VipsForeignFlags = Cvips.VipsForeignFlags

extension VipsForeignFlags {
    public static var none: Self { VIPS_FOREIGN_NONE }
    public static var partial: Self { VIPS_FOREIGN_PARTIAL }
    public static var bigendian: Self { VIPS_FOREIGN_BIGENDIAN }
    public static var sequential: Self { VIPS_FOREIGN_SEQUENTIAL }
    public static var all: Self { VIPS_FOREIGN_ALL }
}