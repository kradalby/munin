import Cvips
import CvipsShim

public typealias VipsOperationRound = Cvips.VipsOperationRound

extension VipsOperationRound {
    public static var rint: Self { VIPS_OPERATION_ROUND_RINT }
    public static var ceil: Self { VIPS_OPERATION_ROUND_CEIL }
    public static var floor: Self { VIPS_OPERATION_ROUND_FLOOR }
    public static var last: Self { VIPS_OPERATION_ROUND_LAST }
}