

extension VIPSImage {
    public static func *(lhs: Double, image: VIPSImage) throws -> VIPSImage {
        return try image.linear(lhs)
    }
    
    public static func *(lhs: VIPSImage, rhs: Double) throws -> VIPSImage {
        return try lhs.linear(rhs)
    }

    public static func *(lhs: VIPSImage, rhs: [Double]) throws -> VIPSImage {
        return try lhs.linear(rhs, [Double].init(repeating: 0, count: rhs.count))
    }
    
    public static func *(lhs: Int, image: VIPSImage) throws -> VIPSImage {
        return try image.linear(lhs)
    }
    
    public static func *(lhs: VIPSImage, rhs: Int) throws -> VIPSImage {
        return try lhs.linear(rhs)
    }
    
    public static func +(lhs: Double, rhs: VIPSImage) throws -> VIPSImage {
        return try rhs.linear(1.0, lhs)
    }
    
    public static func +(lhs: VIPSImage, rhs: Double) throws -> VIPSImage {
        return try lhs.linear(1.0, rhs)
    }

    public static func +(lhs: VIPSImage, rhs: [Double]) throws -> VIPSImage {
        return try lhs.linear([Double].init(repeating: 1.0, count: rhs.count), rhs)
    }
    
    
    public static func +(lhs: Int, rhs: VIPSImage) throws -> VIPSImage {
        return try rhs.linear(1, lhs)
    }
    
    public static func +(lhs: VIPSImage, rhs: Int) throws -> VIPSImage {
        return try lhs.linear(1, rhs)
    }
    
    public static func -(lhs: Int, rhs: VIPSImage) throws -> VIPSImage {
        return try rhs.linear(1, -lhs)
    }
    
    public static func -(lhs: VIPSImage, rhs: Int) throws -> VIPSImage {
        return try lhs.linear(1, -rhs)
    }
    
    
    public static func +(lhs: VIPSImage, rhs: VIPSImage) throws -> VIPSImage {
        return try lhs.add(rhs)
    }
    
    public static func -(lhs: VIPSImage, rhs: VIPSImage) throws -> VIPSImage {
        return try lhs.subtract(rhs)
    }
    
    public static func *(lhs: VIPSImage, rhs: VIPSImage) throws -> VIPSImage {
        return try lhs.multiply(rhs)
    }
    
    public static func /(lhs: VIPSImage, rhs: VIPSImage) throws -> VIPSImage {
        return try lhs.divide(rhs)
    }
    
    // MARK: - Comparison Operators (Element-wise)
    // Note: These return VIPSImage with 255 for true, 0 for false per pixel
    // Cannot conform to Comparable protocol as that requires Bool return type
    
    public static func ==(lhs: VIPSImage, rhs: VIPSImage) throws -> VIPSImage {
        return try lhs.equal(rhs)
    }
    
    public static func !=(lhs: VIPSImage, rhs: VIPSImage) throws -> VIPSImage {
        return try lhs.notequal(rhs)
    }
    
    public static func <(lhs: VIPSImage, rhs: VIPSImage) throws -> VIPSImage {
        return try lhs.less(rhs)
    }
    
    public static func <=(lhs: VIPSImage, rhs: VIPSImage) throws -> VIPSImage {
        return try lhs.lesseq(rhs)
    }
    
    public static func >(lhs: VIPSImage, rhs: VIPSImage) throws -> VIPSImage {
        return try lhs.more(rhs)
    }
    
    public static func >=(lhs: VIPSImage, rhs: VIPSImage) throws -> VIPSImage {
        return try lhs.moreeq(rhs)
    }
    
    // MARK: - Comparison with constants
    
    public static func ==(lhs: VIPSImage, rhs: Double) throws -> VIPSImage {
        return try lhs.equal(rhs)
    }
    
    public static func !=(lhs: VIPSImage, rhs: Double) throws -> VIPSImage {
        return try lhs.notequal(rhs)
    }
    
    public static func <(lhs: VIPSImage, rhs: Double) throws -> VIPSImage {
        return try lhs.less(rhs)
    }
    
    public static func <=(lhs: VIPSImage, rhs: Double) throws -> VIPSImage {
        return try lhs.lesseq(rhs)
    }
    
    public static func >(lhs: VIPSImage, rhs: Double) throws -> VIPSImage {
        return try lhs.more(rhs)
    }
    
    public static func >=(lhs: VIPSImage, rhs: Double) throws -> VIPSImage {
        return try lhs.moreeq(rhs)
    }
    
    // Reverse order for constants
    public static func ==(lhs: Double, rhs: VIPSImage) throws -> VIPSImage {
        return try rhs.equal(lhs)
    }
    
    public static func !=(lhs: Double, rhs: VIPSImage) throws -> VIPSImage {
        return try rhs.notequal(lhs)
    }
    
    public static func <(lhs: Double, rhs: VIPSImage) throws -> VIPSImage {
        return try rhs.more(lhs)  // Note: reversed
    }
    
    public static func <=(lhs: Double, rhs: VIPSImage) throws -> VIPSImage {
        return try rhs.moreeq(lhs)  // Note: reversed
    }
    
    public static func >(lhs: Double, rhs: VIPSImage) throws -> VIPSImage {
        return try rhs.less(lhs)  // Note: reversed
    }
    
    public static func >=(lhs: Double, rhs: VIPSImage) throws -> VIPSImage {
        return try rhs.lesseq(lhs)  // Note: reversed
    }
    
    // MARK: - Bitwise Operators
    
    public static func &(lhs: VIPSImage, rhs: VIPSImage) throws -> VIPSImage {
        return try lhs.andimage(rhs)
    }
    
    public static func |(lhs: VIPSImage, rhs: VIPSImage) throws -> VIPSImage {
        return try lhs.orimage(rhs)
    }
    
    public static func ^(lhs: VIPSImage, rhs: VIPSImage) throws -> VIPSImage {
        return try lhs.eorimage(rhs)
    }
    
    public static func <<(lhs: VIPSImage, rhs: Int) throws -> VIPSImage {
        return try lhs.lshift(rhs)
    }
    
    public static func >>(lhs: VIPSImage, rhs: Int) throws -> VIPSImage {
        return try lhs.rshift(rhs)
    }
}
