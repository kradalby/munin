import Cvips

public func vipsFindLoader(path: String) -> String? {
    guard let cstring = vips_foreign_find_load(path) else {
        return nil
    }
    
    return String(cString: cstring)
}

extension Collection where Element == UInt8 {
    public func vips_findLoader() throws -> String {
        let maybeResult = try self.withContiguousStorageIfAvailable { ptr -> String in
            if let cstring = vips_foreign_find_load_buffer(ptr.baseAddress, ptr.count) {
                return String(cString: cstring)
            } else {
                throw VIPSError()
            }
        }
        
        if let res = maybeResult {
            return res
        } else {
            let array = Array(self)
            guard let cstring = array.withUnsafeBytes({ ptr in
                vips_foreign_find_load_buffer(ptr.baseAddress!, ptr.count)
            }) else {
                throw VIPSError()
            }
            return String(cString: cstring)
        }
    }
}


extension VIPS {
    public static func findLoader(filename: String) -> String? {
        guard let cloader = vips_foreign_find_load(filename) else {
            return nil
        }
        
        return String(cString: cloader)
    }
    
    public static func findLoader<Buffer: Sequence>(buffer: Buffer) throws -> String  where Buffer.Element == UInt8 {
        let maybeResult = try buffer.withContiguousStorageIfAvailable { ptr -> String in
            if let cstring = vips_foreign_find_load_buffer(ptr.baseAddress, ptr.count) {
                return String(cString: cstring)
            } else {
                throw VIPSError()
            }
        }
        
        if let res = maybeResult {
            return res
        } else {
            let array = Array(buffer)
            guard let cstring = array.withUnsafeBytes({ ptr in
                vips_foreign_find_load_buffer(ptr.baseAddress!, ptr.count)
            }) else {
                throw VIPSError()
            }
            return String(cString: cstring)
        }
    }
}