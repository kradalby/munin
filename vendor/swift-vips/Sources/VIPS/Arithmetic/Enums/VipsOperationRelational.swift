import Cvips
import CvipsShim

public typealias VipsOperationRelational = Cvips.VipsOperationRelational

extension VipsOperationRelational {
    public static var equal: Self { VIPS_OPERATION_RELATIONAL_EQUAL }
    public static var noteq: Self { VIPS_OPERATION_RELATIONAL_NOTEQ }
    public static var less: Self { VIPS_OPERATION_RELATIONAL_LESS }
    public static var lesseq: Self { VIPS_OPERATION_RELATIONAL_LESSEQ }
    public static var more: Self { VIPS_OPERATION_RELATIONAL_MORE }
    public static var moreeq: Self { VIPS_OPERATION_RELATIONAL_MOREEQ }
    public static var last: Self { VIPS_OPERATION_RELATIONAL_LAST }
}