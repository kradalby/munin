import Cvips
import CvipsShim

public typealias VipsKernel = Cvips.VipsKernel

extension VipsKernel {
    public static var nearest: Self { VIPS_KERNEL_NEAREST }
    public static var linear: Self { VIPS_KERNEL_LINEAR }
    public static var cubic: Self { VIPS_KERNEL_CUBIC }
    public static var mitchell: Self { VIPS_KERNEL_MITCHELL }
    public static var lanczos2: Self { VIPS_KERNEL_LANCZOS2 }
    public static var lanczos3: Self { VIPS_KERNEL_LANCZOS3 }
    public static var last: Self { VIPS_KERNEL_LAST }
}