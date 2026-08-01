import Cvips
import CvipsShim


extension VIPSImage {
    public func round() throws -> VIPSImage {
        try self.round(.rint)
    }

    public func floor() throws -> VIPSImage {
        try self.round(.floor)
    }

    public func ceil() throws -> VIPSImage {
        try self.round(.ceil)
    }
    
    // MARK: - Trigonometric Functions
    
    /// Calculate sine of image values (in degrees)
    public func sin() throws -> VIPSImage {
        try math(.sin)
    }
    
    /// Calculate cosine of image values (in degrees)
    public func cos() throws -> VIPSImage {
        try math(.cos)
    }
    
    /// Calculate tangent of image values (in degrees)
    public func tan() throws -> VIPSImage {
        try math(.tan)
    }
    
    /// Calculate arcsine of image values (result in degrees)
    public func asin() throws -> VIPSImage {
        try math(.asin)
    }
    
    /// Calculate arccosine of image values (result in degrees)
    public func acos() throws -> VIPSImage {
        try math(.acos)
    }
    
    /// Calculate arctangent of image values (result in degrees)
    public func atan() throws -> VIPSImage {
        try math(.atan)
    }
    
    // MARK: - Hyperbolic Functions
    
    /// Calculate hyperbolic sine of image values
    public func sinh() throws -> VIPSImage {
        try math(.sinh)
    }
    
    /// Calculate hyperbolic cosine of image values
    public func cosh() throws -> VIPSImage {
        try math(.cosh)
    }
    
    /// Calculate hyperbolic tangent of image values
    public func tanh() throws -> VIPSImage {
        try math(.tanh)
    }
    
    /// Calculate inverse hyperbolic sine of image values
    public func asinh() throws -> VIPSImage {
        try math(.asinh)
    }
    
    /// Calculate inverse hyperbolic cosine of image values
    public func acosh() throws -> VIPSImage {
        try math(.acosh)
    }
    
    /// Calculate inverse hyperbolic tangent of image values
    public func atanh() throws -> VIPSImage {
        try math(.atanh)
    }
    
    // MARK: - Exponential and Logarithmic Functions
    
    /// Calculate e^x for each pixel
    public func exp() throws -> VIPSImage {
        try math(.exp)
    }
    
    /// Calculate 10^x for each pixel
    public func exp10() throws -> VIPSImage {
        try math(.exp10)
    }
    
    /// Calculate natural logarithm (ln) of each pixel
    public func log() throws -> VIPSImage {
        try math(.log)
    }
    
    /// Calculate base-10 logarithm of each pixel
    public func log10() throws -> VIPSImage {
        try math(.log10)
    }
    
    // MARK: - Math2 Operations
    
    /// Raise image values to the power of another image
    public func pow(_ exponent: VIPSImage) throws -> VIPSImage {
        try math2(exponent, math2: .pow)
    }
    
    /// Raise image values to a constant power
    public func pow(_ exponent: Double) throws -> VIPSImage {
        try math2Const(math2: .pow, c: [exponent])
    }
    
    /// Raise image values to a constant power (integer overload)
    public func pow(_ exponent: Int) throws -> VIPSImage {
        try math2Const(math2: .pow, c: [Double(exponent)])
    }
    
    /// Raise another image to the power of this image (swapped arguments)
    public func wop(_ base: VIPSImage) throws -> VIPSImage {
        try math2(base, math2: .wop)
    }
    
    /// Raise a constant to the power of this image
    public func wop(_ base: Double) throws -> VIPSImage {
        try math2Const(math2: .wop, c: [base])
    }
    
    /// Raise a constant to the power of this image (integer overload)
    public func wop(_ base: Int) throws -> VIPSImage {
        try math2Const(math2: .wop, c: [Double(base)])
    }
    
    /// Calculate two-argument arctangent of y/x in degrees
    public func atan2(_ x: VIPSImage) throws -> VIPSImage {
        try math2(x, math2: .atan2)
    }
    
    // MARK: - Complex Operations
    
    /// Convert complex image to polar form
    public func polar() throws -> VIPSImage {
        try complex(cmplx: .polar)
    }
    
    /// Convert polar image to rectangular form
    public func rect() throws -> VIPSImage {
        try complex(cmplx: .rect)
    }
    
    /// Calculate complex conjugate
    public func conj() throws -> VIPSImage {
        try complex(cmplx: .conj)
    }
    
    /// Extract real part of complex image
    public func real() throws -> VIPSImage {
        try complexget(get: .real)
    }
    
    /// Extract imaginary part of complex image
    public func imag() throws -> VIPSImage {
        try complexget(get: .imag)
    }
    
    /// Create a complex image from real and imaginary parts
    public func complex(_ imaginary: VIPSImage) throws -> VIPSImage {
        try complexform(imaginary)
    }
    
    // MARK: - Bitwise Operations Overloads
    
    /// Bitwise XOR of image with a constant
    public func eorimage(_ value: Double) throws -> VIPSImage {
        try booleanConst(boolean: .eor, c: [value])
    }
    
    /// Bitwise XOR of image with a constant (integer overload)
    public func eorimage(_ value: Int) throws -> VIPSImage {
        try booleanConst(boolean: .eor, c: [Double(value)])
    }
    
    /// Bitwise AND of image with a constant
    public func andimage(_ value: Double) throws -> VIPSImage {
        try booleanConst(boolean: .and, c: [value])
    }
    
    /// Bitwise AND of image with a constant (integer overload)
    public func andimage(_ value: Int) throws -> VIPSImage {
        try booleanConst(boolean: .and, c: [Double(value)])
    }
    
    /// Bitwise OR of image with a constant
    public func orimage(_ value: Double) throws -> VIPSImage {
        try booleanConst(boolean: .or, c: [value])
    }
    
    /// Bitwise OR of image with a constant (integer overload)
    public func orimage(_ value: Int) throws -> VIPSImage {
        try booleanConst(boolean: .or, c: [Double(value)])
    }
    
    /// Left shift with an image of shift amounts
    public func lshift(_ shiftAmounts: VIPSImage) throws -> VIPSImage {
        try boolean(shiftAmounts, boolean: .lshift)
    }
    
    /// Right shift with an image of shift amounts  
    public func rshift(_ shiftAmounts: VIPSImage) throws -> VIPSImage {
        try boolean(shiftAmounts, boolean: .rshift)
    }
    
    /// Pass an image through a linear transform, ie. (out = in * a + b). Output is float 
    /// for integer input, double for double input, complex for complex input and double 
    /// complex for double complex input. Set uchar to output uchar pixels.
    /// 
    /// If the arrays of constants have just one element, that constant is used for all image 
    /// bands. If the arrays have more than one element and they have the same number of elements 
    /// as there are bands in the image, then one array element is used for each band. If the 
    /// arrays have more than one element and the image only has a single band, the result is 
    /// a many-band image where each band corresponds to one array element.
    public func linear(_ a: Double = 1.0, _ b: Double = 0, uchar: Bool? = nil) throws -> VIPSImage {
        return try VIPSImage { out in
            var opt = VIPSOption()
            
            opt.set("in", value: self.image)
            opt.set("a", value: [ a ])
            opt.set("b", value: [ b ])
            opt.set("out", value: &out)
            if let uchar = uchar {
                opt.set("uchar", value: uchar)
            }

            try VIPSImage.call("linear", options: &opt)
        }
    }
    
    public func linear(_ a: Int = 1, _ b: Int = 0, uchar: Bool? = nil) throws -> VIPSImage {
        return try linear(Double(a), Double(b), uchar: uchar)
    }

    public func linear(_ a: [Double], _ b: [Double], uchar: Bool? = nil) throws -> VIPSImage {
        return try VIPSImage { out in
            var opt = VIPSOption()
            
            opt.set("in", value: self.image)
            opt.set("a", value: a)
            opt.set("b", value: b)
            opt.set("out", value: &out)
            if let uchar = uchar {
                opt.set("uchar", value: uchar)
            }

            try VIPSImage.call("linear", options: &opt)
        }
    }
}