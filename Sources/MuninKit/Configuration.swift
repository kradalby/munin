import Foundation

/// Modern configuration system using Codable to replace the deprecated Configuration package
public struct MuninConfiguration: Codable {
    let people: [String]
    let peopleFiles: [String]
    let resolutions: [Int]
    let jpegCompression: Double
    let sourceFolder: String
    let targetFolder: String
    let fileExtensions: [String]
    let concurrency: Int
    let logPath: String?
    let logLevel: String?
    let diff: Bool
    let progress: Bool
    
    enum CodingKeys: String, CodingKey {
        case people
        case peopleFiles
        case resolutions
        case jpegCompression
        case sourceFolder
        case targetFolder
        case fileExtensions
        case concurrency
        case logPath
        case logLevel
        case diff
        case progress
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        people = try container.decodeIfPresent([String].self, forKey: .people) ?? []
        peopleFiles = try container.decodeIfPresent([String].self, forKey: .peopleFiles) ?? []
        resolutions = try container.decodeIfPresent([Int].self, forKey: .resolutions) ?? [1600, 1200, 992, 768, 576, 340, 220, 180]
        jpegCompression = try container.decodeIfPresent(Double.self, forKey: .jpegCompression) ?? 1.0
        sourceFolder = try container.decodeIfPresent(String.self, forKey: .sourceFolder) ?? ""
        targetFolder = try container.decodeIfPresent(String.self, forKey: .targetFolder) ?? ""
        fileExtensions = try container.decodeIfPresent([String].self, forKey: .fileExtensions) ?? ["jpg", "jpeg", "JPG", "JPEG"]
        concurrency = try container.decodeIfPresent(Int.self, forKey: .concurrency) ?? ProcessInfo.processInfo.processorCount
        logPath = try container.decodeIfPresent(String.self, forKey: .logPath)
        logLevel = try container.decodeIfPresent(String.self, forKey: .logLevel)
        diff = try container.decodeIfPresent(Bool.self, forKey: .diff) ?? false
        progress = try container.decodeIfPresent(Bool.self, forKey: .progress) ?? true
    }
    
    public init(
        people: [String] = [],
        peopleFiles: [String] = [],
        resolutions: [Int] = [1600, 1200, 992, 768, 576, 340, 220, 180],
        jpegCompression: Double = 1.0,
        sourceFolder: String = "",
        targetFolder: String = "",
        fileExtensions: [String] = ["jpg", "jpeg", "JPG", "JPEG"],
        concurrency: Int = ProcessInfo.processInfo.processorCount,
        logPath: String? = nil,
        logLevel: String? = nil,
        diff: Bool = false,
        progress: Bool = true
    ) {
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
}

/// Configuration manager that handles loading from files and environment
public struct ConfigurationManager {
    private var config: MuninConfiguration
    private var overrides: [String: Any] = [:]
    
    public init() {
        self.config = MuninConfiguration()
    }
    
    @discardableResult
    public mutating func load(file path: String, relativeFrom: ConfigurationRelativePath = .pwd) -> Self {
        let fullPath: String
        switch relativeFrom {
        case .pwd:
            fullPath = path
        case .customPath(let basePath):
            if basePath.isEmpty {
                fullPath = path
            } else {
                fullPath = basePath + "/" + path
            }
        }
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
              let loadedConfig = try? JSONDecoder().decode(MuninConfiguration.self, from: data) else {
            // If file doesn't exist or can't be parsed, continue with defaults
            return self
        }
        self.config = loadedConfig
        return self
    }
    
    @discardableResult
    public mutating func load(_ source: ConfigurationSource) -> Self {
        switch source {
        case .environmentVariables:
            loadEnvironmentVariables()
        case .commandLineArguments:
            loadCommandLineArguments()
        }
        return self
    }
    
    @discardableResult
    public mutating func load(_ values: [String: Any]) -> Self {
        // Merge values into overrides
        for (key, value) in values {
            overrides[key] = value
        }
        return self
    }
    
    private mutating func loadEnvironmentVariables() {
        let env = ProcessInfo.processInfo.environment
        
        if let people = env["MUNIN_PEOPLE"]?.components(separatedBy: ",") {
            overrides["people"] = people
        }
        if let resolutions = env["MUNIN_RESOLUTIONS"]?.components(separatedBy: ",").compactMap(Int.init) {
            overrides["resolutions"] = resolutions
        }
        if let compression = env["MUNIN_JPEG_COMPRESSION"].flatMap(Double.init) {
            overrides["jpegCompression"] = compression
        }
        if let sourceFolder = env["MUNIN_SOURCE_FOLDER"] {
            overrides["sourceFolder"] = sourceFolder
        }
        if let targetFolder = env["MUNIN_TARGET_FOLDER"] {
            overrides["targetFolder"] = targetFolder
        }
        if let concurrency = env["MUNIN_CONCURRENCY"].flatMap(Int.init) {
            overrides["concurrency"] = concurrency
        }
        if let logLevel = env["MUNIN_LOG_LEVEL"] {
            overrides["logLevel"] = logLevel
        }
        if let diff = env["MUNIN_DIFF"].flatMap(Bool.init) {
            overrides["diff"] = diff
        }
        if let progress = env["MUNIN_PROGRESS"].flatMap(Bool.init) {
            overrides["progress"] = progress
        }
    }
    
    private mutating func loadCommandLineArguments() {
        // Command line argument parsing is handled by ArgumentParser in main.swift
        // This is just a placeholder for consistency with the original API
    }
    
    public subscript(key: String) -> Any? {
        if let override = overrides[key] {
            return override
        }
        
        switch key {
        case "people": return config.people
        case "peopleFiles": return config.peopleFiles
        case "resolutions": return config.resolutions
        case "jpegCompression": return config.jpegCompression
        case "sourceFolder": return config.sourceFolder
        case "targetFolder": return config.targetFolder
        case "fileExtensions": return config.fileExtensions
        case "concurrency": return config.concurrency
        case "logPath": return config.logPath
        case "logLevel": return config.logLevel
        case "diff": return config.diff
        case "progress": return config.progress
        default: return nil
        }
    }
}

public enum ConfigurationRelativePath {
    case pwd
    case customPath(String)
}

public enum ConfigurationSource {
    case environmentVariables
    case commandLineArguments
}