import Cvips
import CvipsShim

public typealias VipsOperationComplex2 = Cvips.VipsOperationComplex2

extension VipsOperationComplex2 {
    public static var crossPhase: Self { VIPS_OPERATION_COMPLEX2_CROSS_PHASE }
    public static var last: Self { VIPS_OPERATION_COMPLEX2_LAST }
}