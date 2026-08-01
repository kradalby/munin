import Cvips
import CvipsShim

func logfunc(_ domain: UnsafePointer<gchar>!, _ loglevel: GLogLevelFlags, _ msg: UnsafePointer<gchar>!, _ userdata: gpointer!) {
    let logger : VIPSLoggingDelegate = Unmanaged<AnyObject>.fromOpaque(userdata).takeUnretainedValue() as! VIPSLoggingDelegate
    // Bit test rather than a switch on G_LOG_LEVEL_*: glib >= 2.86 tags
    // GLogLevelFlags with __attribute__((flag_enum)) and Swift stops importing
    // those enumerators as globals. `rawValue` exists under both imports.
    let bits = UInt32(truncatingIfNeeded: loglevel.rawValue)
    if bits & shim_G_LOG_LEVEL_ERROR() != 0 {
        logger.error("\(String(cString: msg))")
    } else if bits & shim_G_LOG_LEVEL_WARNING() != 0 {
        logger.warning("\(String(cString: msg))")
    } else if bits & shim_G_LOG_LEVEL_INFO() != 0 {
        logger.info("\(String(cString: msg))")
    } else {
        logger.debug("\(String(cString: msg))")
    }
}

public protocol VIPSLoggingDelegate: AnyObject {
    func debug(_ message: String)
    func info(_ message: String)
    func warning(_ message: String)
    func error(_ message: String)
}
