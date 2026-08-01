import Cvips

public struct VIPSError: Error, CustomStringConvertible {
    public let message: String

    @usableFromInline
    init(_ errorBuffer: UnsafePointer<Int8>! = vips_error_buffer()) {
        self.message = String(cString: errorBuffer)
        vips_error_clear()
    }

    @usableFromInline
    init(_ message: String) {
        self.message = message
    }
    
    public var description: String { self.message }
}