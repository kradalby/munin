import Cvips
import CvipsShim

struct VIPSOperation: ~Copyable {
    init(_ op: UnsafeMutablePointer<VipsOperation>!) {
        self.op = op
    }

    var op: UnsafeMutablePointer<VipsOperation>!


    init(name: String) throws {
        let op = vips_operation_new(name)
        guard op != nil else { throw VIPSError() }
        self.init(op)
    }
    
    init(name: UnsafePointer<CChar>!) throws {
        let op = vips_operation_new(name)
        guard op != nil else { throw VIPSError() }
        self.init(op)
    }
    
    func setFromString(options: String) throws {
        guard vips_object_set_from_string( shim_vips_object( self.op ), options) == 0 else {
            throw VIPSError()
        }
    }
    
    func set(option: VIPSOption) {
        for pair in option.pairs where pair.input == true {
            g_object_set_property( shim_g_object(op) , pair.name, &pair.value)
        }
    }
    
    func get(option: inout VIPSOption) {
        for i in 0..<option.pairs.count {
            if option.pairs[i].input == true { continue }
            g_object_get_property( shim_g_object(self.op) , option.pairs[i].name, &option.pairs[i].value)
            switch option.pairs[i].output {
            case .some(.image(let image)):
                let obj = shim_vips_image( g_value_get_object(&option.pairs[i].value) )
                image.pointee = obj!
            case .some(.double(let value)):
                value?.pointee = g_value_get_double(&option.pairs[i].value)
            case .some(.blob(let blob)):
                blob.pointee = g_value_get_boxed(&option.pairs[i].value).assumingMemoryBound(to: VipsBlob.self)
            case .some(.integer(let value)):
                value?.pointee = Int(g_value_get_int(&option.pairs[i].value))
            case .some(.boolean(let bool)):
                bool?.pointee = g_value_get_boolean(&option.pairs[i].value) != 0
            case .some(.doubleArray(let outArray)):
                var length = Int32(0)
                let data = vips_value_get_array_double(&option.pairs[i].value, &length)
                let vipsArray = vips_array_double_new(data, length)
                outArray.pointee = vipsArray!
            case .none:
                assertionFailure("no output specified for output value")
            }
        }
    }
    
    deinit {
        guard self.op != nil else { return }
        vips_object_unref_outputs( shim_vips_object(self.op) )
        g_object_unref(self.op)
    }
}