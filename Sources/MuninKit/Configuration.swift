import Foundation

/// JSON-shaped configuration values that back a Munin gallery build.
///
/// `MuninConfiguration` replaces the previous `Kitura/Configuration`
/// dependency. It is `Codable` so it can be loaded directly from the
/// on-disk `munin.json` format, and `Sendable` so it can cross actor
/// boundaries freely.
public struct MuninConfiguration: Codable, Sendable {
  public var name: String
  public var people: [String]
  public var peopleFiles: [String]
  public var resolutions: [Int]
  public var jpegCompression: Double
  public var sourceFolder: String
  public var targetFolder: String
  public var fileExtensions: [String]
  public var concurrency: Int
  public var logPath: String?
  public var logLevel: String?
  public var diff: Bool
  public var progress: Bool

  public static let defaultResolutions: [Int] = [1600, 1200, 992, 768, 576, 340, 220, 180]
  public static let defaultFileExtensions: [String] = ["jpg", "jpeg", "JPG", "JPEG"]

  public init(
    name: String = "root",
    people: [String] = [],
    peopleFiles: [String] = [],
    resolutions: [Int] = MuninConfiguration.defaultResolutions,
    jpegCompression: Double = 1.0,
    sourceFolder: String = "",
    targetFolder: String = "",
    fileExtensions: [String] = MuninConfiguration.defaultFileExtensions,
    concurrency: Int = ProcessInfo.processInfo.processorCount,
    logPath: String? = nil,
    logLevel: String? = nil,
    diff: Bool = false,
    progress: Bool = true
  ) {
    self.name = name
    self.people = people
    self.peopleFiles = peopleFiles
    self.resolutions = resolutions
    self.jpegCompression = jpegCompression
    self.sourceFolder = sourceFolder
    self.targetFolder = targetFolder
    self.fileExtensions = fileExtensions
    self.concurrency = concurrency
    self.logPath = logPath
    self.logLevel = logLevel
    self.diff = diff
    self.progress = progress
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let defaults = MuninConfiguration()
    self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? defaults.name
    self.people = try container.decodeIfPresent([String].self, forKey: .people) ?? defaults.people
    self.peopleFiles =
      try container.decodeIfPresent([String].self, forKey: .peopleFiles) ?? defaults.peopleFiles
    self.resolutions =
      try container.decodeIfPresent([Int].self, forKey: .resolutions) ?? defaults.resolutions
    self.jpegCompression =
      try container.decodeIfPresent(Double.self, forKey: .jpegCompression)
      ?? defaults.jpegCompression
    self.sourceFolder =
      try container.decodeIfPresent(String.self, forKey: .sourceFolder) ?? defaults.sourceFolder
    self.targetFolder =
      try container.decodeIfPresent(String.self, forKey: .targetFolder) ?? defaults.targetFolder
    self.fileExtensions =
      try container.decodeIfPresent([String].self, forKey: .fileExtensions)
      ?? defaults.fileExtensions
    self.concurrency =
      try container.decodeIfPresent(Int.self, forKey: .concurrency) ?? defaults.concurrency
    self.logPath = try container.decodeIfPresent(String.self, forKey: .logPath)
    self.logLevel = try container.decodeIfPresent(String.self, forKey: .logLevel)
    self.diff = try container.decodeIfPresent(Bool.self, forKey: .diff) ?? defaults.diff
    self.progress = try container.decodeIfPresent(Bool.self, forKey: .progress) ?? defaults.progress
  }
}

/// How a file path passed to `ConfigurationManager.load(file:relativeFrom:)`
/// should be resolved.
public enum ConfigurationRelativePath: Sendable {
  /// Resolve relative to the current working directory.
  case pwd
  /// Resolve relative to a caller-supplied base directory.
  case customPath(String)
}

/// Non-file configuration sources.
public enum ConfigurationSource: Sendable {
  case environmentVariables
  case commandLineArguments
}

/// Layered configuration builder.
///
/// Usage matches the pattern the previous `Kitura/Configuration` surface
/// exposed — build up sources in order of increasing priority, then query
/// via the subscript:
///
/// ```swift
/// let manager = ConfigurationManager()
/// manager
///   .load(file: "munin.json", relativeFrom: .pwd)
///   .load(.environmentVariables)
///   .load(.commandLineArguments)
/// let people = manager["people"] as? [String] ?? []
/// ```
///
/// The order of precedence (lowest → highest) is:
/// 1. Defaults in `MuninConfiguration`
/// 2. File contents loaded via `load(file:relativeFrom:)`
/// 3. Environment variables / command-line arguments
/// 4. Dictionary overrides passed to `load(_:)`
public final class ConfigurationManager {
  private var base: MuninConfiguration
  private var overrides: [String: Any] = [:]

  public init() {
    self.base = MuninConfiguration()
  }

  @discardableResult
  public func load(
    file path: String,
    relativeFrom: ConfigurationRelativePath = .pwd
  ) -> ConfigurationManager {
    let resolvedPath: String
    switch relativeFrom {
    case .pwd:
      resolvedPath = path
    case .customPath(let basePath):
      resolvedPath = basePath.isEmpty ? path : basePath + "/" + path
    }
    guard
      let data = try? Data(contentsOf: URL(fileURLWithPath: resolvedPath)),
      let loaded = try? JSONDecoder().decode(MuninConfiguration.self, from: data)
    else {
      return self
    }
    self.base = loaded
    return self
  }

  @discardableResult
  public func load(_ source: ConfigurationSource) -> ConfigurationManager {
    switch source {
    case .environmentVariables:
      loadEnvironmentVariables()
    case .commandLineArguments:
      loadCommandLineArguments()
    }
    return self
  }

  @discardableResult
  public func load(_ values: [String: Any]) -> ConfigurationManager {
    for (key, value) in values {
      overrides[key] = value
    }
    return self
  }

  /// Look up a configuration value by key, honouring the layered precedence.
  public subscript(key: String) -> Any? {
    if let override = overrides[key] {
      return override
    }
    return baseValue(for: key)
  }

  private func baseValue(for key: String) -> Any? {
    switch key {
    case "name": return base.name
    case "people": return base.people
    case "peopleFiles": return base.peopleFiles
    case "resolutions": return base.resolutions
    case "jpegCompression": return base.jpegCompression
    case "sourceFolder": return base.sourceFolder
    case "targetFolder": return base.targetFolder
    case "fileExtensions": return base.fileExtensions
    case "concurrency": return base.concurrency
    case "logPath": return base.logPath
    case "logLevel": return base.logLevel
    case "diff": return base.diff
    case "progress": return base.progress
    default: return nil
    }
  }

  private func loadEnvironmentVariables() {
    let env = ProcessInfo.processInfo.environment
    if let v = env["MUNIN_NAME"] {
      overrides["name"] = v
    }
    if let v = env["MUNIN_PEOPLE"] {
      overrides["people"] = v.components(separatedBy: ",")
    }
    if let v = env["MUNIN_PEOPLE_FILES"] {
      overrides["peopleFiles"] = v.components(separatedBy: ",")
    }
    if let v = env["MUNIN_RESOLUTIONS"] {
      overrides["resolutions"] = v.components(separatedBy: ",").compactMap(Int.init)
    }
    if let v = env["MUNIN_JPEG_COMPRESSION"], let d = Double(v) {
      overrides["jpegCompression"] = d
    }
    if let v = env["MUNIN_SOURCE_FOLDER"] {
      overrides["sourceFolder"] = v
    }
    if let v = env["MUNIN_TARGET_FOLDER"] {
      overrides["targetFolder"] = v
    }
    if let v = env["MUNIN_FILE_EXTENSIONS"] {
      overrides["fileExtensions"] = v.components(separatedBy: ",")
    }
    if let v = env["MUNIN_CONCURRENCY"], let i = Int(v) {
      overrides["concurrency"] = i
    }
    if let v = env["MUNIN_LOG_PATH"] {
      overrides["logPath"] = v
    }
    if let v = env["MUNIN_LOG_LEVEL"] {
      overrides["logLevel"] = v
    }
    if let v = env["MUNIN_DIFF"] {
      overrides["diff"] = (v as NSString).boolValue
    }
    if let v = env["MUNIN_PROGRESS"] {
      overrides["progress"] = (v as NSString).boolValue
    }
  }

  private func loadCommandLineArguments() {
    // Accepts `--key=value` and `--key value` forms for the recognised keys.
    // This mirrors the subset the previous Kitura manager parsed; the CLI
    // itself uses swift-argument-parser for structured options.
    let args = CommandLine.arguments.dropFirst()
    var iterator = args.makeIterator()
    while let arg = iterator.next() {
      guard arg.hasPrefix("--") else { continue }
      let stripped = String(arg.dropFirst(2))
      let key: String
      let valueString: String
      if let eq = stripped.firstIndex(of: "=") {
        key = String(stripped[..<eq])
        valueString = String(stripped[stripped.index(after: eq)...])
      } else {
        key = stripped
        guard let next = iterator.next() else { continue }
        valueString = next
      }
      guard baseValue(for: key) != nil else { continue }
      overrides[key] = coerce(valueString, forKey: key)
    }
  }

  private func coerce(_ value: String, forKey key: String) -> Any {
    switch key {
    case "resolutions":
      return value.components(separatedBy: ",").compactMap(Int.init)
    case "people", "peopleFiles", "fileExtensions":
      return value.components(separatedBy: ",")
    case "jpegCompression":
      return Double(value) ?? value
    case "concurrency":
      return Int(value) ?? value
    case "diff", "progress":
      return (value as NSString).boolValue
    default:
      return value
    }
  }
}
