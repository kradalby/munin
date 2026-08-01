import Cvips
import CvipsShim

public typealias VipsOperationComplex = Cvips.VipsOperationComplex

extension VipsOperationComplex {
    public static var polar: Self { VIPS_OPERATION_COMPLEX_POLAR }
    public static var rect: Self { VIPS_OPERATION_COMPLEX_RECT }
    public static var conj: Self { VIPS_OPERATION_COMPLEX_CONJ }
    public static var last: Self { VIPS_OPERATION_COMPLEX_LAST }
}