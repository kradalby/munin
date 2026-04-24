import Foundation
import SystemPackage

/// Errors produced by MuninKit.
///
/// This enum is intentionally small today — most of the existing codebase
/// swallows errors with `try?` and a log line. As error surfaces are made
/// more deliberate, new cases should be added here rather than one-off
/// `NSError` or stringly-typed errors.
public enum MuninError: Error, Sendable {
  /// A configuration file was requested but could not be read or parsed.
  case configurationFileUnreadable(path: String, underlying: String)

  /// A configuration file decoded but failed its semantic validation.
  case configurationInvalid(reason: String)

  /// A directory could not be created or written into.
  case directoryCreationFailed(path: String, underlying: String)

  /// Writing the gallery JSON for a node failed.
  case metadataWriteFailed(path: String, underlying: String)

  /// An image read/decode/resize/write operation failed.
  case imageOperationFailed(path: String, operation: String, underlying: String)

  /// A low-level POSIX syscall (open/read/write/stat/unlink/…) returned an
  /// error. The path is captured so callers don't have to re-plumb it into
  /// log lines; the `Errno` preserves the raw error code for decisions like
  /// "ignore ENOENT here" at the call site.
  case ioFailure(operation: String, path: FilePath, errno: Errno)
}

extension MuninError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .configurationFileUnreadable(let path, let underlying):
      return "Configuration file '\(path)' could not be read: \(underlying)"
    case .configurationInvalid(let reason):
      return "Configuration is invalid: \(reason)"
    case .directoryCreationFailed(let path, let underlying):
      return "Could not create directory '\(path)': \(underlying)"
    case .metadataWriteFailed(let path, let underlying):
      return "Could not write metadata to '\(path)': \(underlying)"
    case .imageOperationFailed(let path, let operation, let underlying):
      return "Image \(operation) failed for '\(path)': \(underlying)"
    case .ioFailure(let operation, let path, let errno):
      return "\(operation) failed for '\(path)': \(errno)"
    }
  }
}
