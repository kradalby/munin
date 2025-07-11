import Foundation

/// Protocol for progress animations - replaces TSC ProgressAnimationProtocol
public protocol ProgressAnimationProtocol {
    func update(step: Int, total: Int, text: String)
    func complete(success: Bool)
    func clear()
}

/// Simple console-based progress animation for writing/processing
public final class PercentProgressAnimation: ProgressAnimationProtocol {
    private let header: String
    private var hasDisplayedHeader = false
    private var lastOutput = ""
    
    public init(header: String) {
        self.header = header
    }
    
    public func update(step: Int, total: Int, text: String) {
        if !hasDisplayedHeader {
            print(header)
            hasDisplayedHeader = true
        }
        
        let percentage = total > 0 ? Double(step) / Double(total) * 100 : 0
        let output = String(format: "%.1f%% (%d/%d) %@", percentage, step, total, text)
        
        // Clear previous line if we're updating
        if !lastOutput.isEmpty {
            print("\r\u{001B}[K", terminator: "")
        }
        
        print("\r\(output)", terminator: "")
        lastOutput = output
        fflush(Foundation.stdout)
    }
    
    public func complete(success: Bool) {
        print() // Move to next line
        let status = success ? "✓ Complete" : "✗ Failed"
        print(status)
    }
    
    public func clear() {
        print("\r\u{001B}[K", terminator: "")
        lastOutput = ""
    }
}

/// Simple console-based animation for reading/discovery phase
public final class ReadingProgressAnimation: ProgressAnimationProtocol {
    private let header: String
    private var hasDisplayedHeader = false
    private var lastOutput = ""
    
    public init(header: String) {
        self.header = header
    }
    
    public func update(step: Int, total: Int, text: String) {
        if !hasDisplayedHeader {
            print(header)
            hasDisplayedHeader = true
        }
        
        let output = "Found: [\(step)] \(text)"
        
        // Clear previous line if we're updating
        if !lastOutput.isEmpty {
            print("\r\u{001B}[K", terminator: "")
        }
        
        print("\r\(output)", terminator: "")
        lastOutput = output
        fflush(Foundation.stdout)
    }
    
    public func complete(success: Bool) {
        print() // Move to next line
        let status = success ? "✓ Discovery complete" : "✗ Discovery failed"
        print(status)
    }
    
    public func clear() {
        print("\r\u{001B}[K", terminator: "")
        lastOutput = ""
    }
}

/// Simple terminal output stream replacement for TSCBasic.stdoutStream
@MainActor
public final class OutputWriter: Sendable {
    public static let stdout = OutputWriter()
    
    private init() {}
    
    public func write(_ string: String) {
        print(string, terminator: "")
        fflush(Foundation.stdout)
    }
    
    public func writeLine(_ string: String) {
        print(string)
    }
}