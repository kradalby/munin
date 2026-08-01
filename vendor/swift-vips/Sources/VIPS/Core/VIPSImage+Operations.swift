import Cvips
import CvipsShim

extension VIPSImage {
    public func fit(width: Int, height: Int?, size: VipsSize = .down) throws -> VIPSImage {
        let currentSize = self.size
        let ar =  Double(currentSize.width) / Double(currentSize.height)
        
        var bh: Int
        if let h = height {
            bh = h
        } else {
            bh = Int(Double(width) / ar)
        }
        
        let scaleX = Double(width) / Double(currentSize.width)
        let scaleY = Double(bh)    / Double(currentSize.height)
        
        func effective(scale: Double) -> Double {
            switch size {
            case .both:
                return scale
            case .down:
                return Swift.min(scale, 1.0)
            case .up:
                return Swift.max(scale, 1.0)
            default:
                return scale
            }
        }
        
        if scaleX < scaleY {
            return try self.resize(scale: effective(scale: scaleX))
        } else {
            return try self.resize(scale: effective(scale: scaleY))
        }
        
    }
    
    
    /// Same as `autorot()`
    /// 
    /// See: `VIPSImage.autorot()`
    public func autorotate() throws -> VIPSImage {
        return try self.autorot()
    }
}