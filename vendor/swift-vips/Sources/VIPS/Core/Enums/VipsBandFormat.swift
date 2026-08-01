import Cvips
import CvipsShim

public typealias VipsBandFormat = Cvips.VipsBandFormat

extension VipsBandFormat {
    public static var notset: Self { VIPS_FORMAT_NOTSET }
    public static var uchar: Self { VIPS_FORMAT_UCHAR }
    public static var char: Self { VIPS_FORMAT_CHAR }
    public static var ushort: Self { VIPS_FORMAT_USHORT }
    public static var short: Self { VIPS_FORMAT_SHORT }
    public static var uint: Self { VIPS_FORMAT_UINT }
    public static var int: Self { VIPS_FORMAT_INT }
    public static var float: Self { VIPS_FORMAT_FLOAT }
    public static var complex: Self { VIPS_FORMAT_COMPLEX }
    public static var double: Self { VIPS_FORMAT_DOUBLE }
    public static var dpcomplex: Self { VIPS_FORMAT_DPCOMPLEX }
    public static var last: Self { VIPS_FORMAT_LAST }
}

extension VipsBandFormat {
    /// The maximum numeric value possible for this band format.
    /// 
    /// Returns the largest value that can be represented in this format.
    /// For example:
    /// - `.uchar` returns 255
    /// - `.ushort` returns 65535
    /// - `.float` returns 1.0
    /// 
    /// - Returns: The maximum value for this format
    public var max: Double {
        return vips_image_get_format_max(self)
    }
}