import Foundation

import Rainbow

public struct Logger {
    public func debug(_ message: Any) {
        print("[DEBUG] ".lightCyan + "\(message)")
    }
    public func warning(_ message: Any) {
        print("[WARNING] ".yellow + "\(message)")
    }
    public func info(_ message: Any) {
        print("[INFO] ".green + "\(message)")
    }
    public func trace(_ message: Any) {
        print("[TRACE] ".white + "\(message)")
    }
    public func error(_ message: Any) {
        print("[ERROR] ".red + "\(message)")
    }
    
    public init () {
        
    }
}


