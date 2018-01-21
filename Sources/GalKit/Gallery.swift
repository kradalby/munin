//
//  Gallery.swift
//  GalPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Foundation
import Config
import Logger

let concurrentPhotoQueue =
    DispatchQueue(
        label: "no.kradalby.gal.Gallery",
        attributes: .concurrent)

let concurrentDispatchGroup = DispatchGroup()

var log = Logger(LogLevel.INFO)

public struct GalleryConfiguration: Configuration {
    var name: String
    var people: [String]
    var resolutions: [Int]
    var jpegCompression: Double
    var inputPath: String
    var outputPath: String
    var fileExtentions: [String]
    public var logLevel: Int
    
    enum CodingKeys: String, CodingKey
    {
        case name
        case people
        case resolutions
        case jpegCompression
        case inputPath
        case outputPath
        case fileExtentions
        case logLevel
    }
    
    public init(from decoder: Decoder) throws
    {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try values.decode(String.self, forKey: .name)
        self.people = try values.decode([String].self, forKey: .people)
        self.resolutions = try values.decode([Int].self, forKey: .resolutions)
        self.jpegCompression = try values.decode(Double.self, forKey: .jpegCompression)
        self.inputPath = try values.decode(String.self, forKey: .inputPath)
        self.outputPath = try values.decode(String.self, forKey: .outputPath)
        self.fileExtentions = try values.decode([String].self, forKey: .fileExtentions)
        self.logLevel = try values.decode(Int.self, forKey: .logLevel)
    }
}

public struct Gallery {
    var input: Album
    var output: Album?
    var config: GalleryConfiguration
    
    public init(config: GalleryConfiguration) {
        self.config = config
        
        log = Logger(config.logLevel)
        
        // read input directory
        let inputStart = Date()
        self.input = readStateFromInputDirectory(atPath: config.inputPath, outPath: config.outputPath, name: config.name, config: config)
        let inputEnd = Date()
        log.info("Input directory read in \(inputEnd.timeIntervalSince(inputStart)) seconds")
        
        let outputStart = Date()
        if let album = readStateFromOutputDirectory(indexFileAtPath: "\(config.outputPath)/\(config.name)/index.json") {
            self.output = album
        } else {
            log.info("Could not find any output album, assuming new is to be created")
        }
        let outputEnd = Date()
        log.debug("Output directory read in \(outputEnd.timeIntervalSince(outputStart)) seconds")

        
        log.debug("Input album differs from output album: \(self.input != self.output)")
        log.debug("Input: \n\(self.input)")
        if let out = self.output {
            log.debug("Output: \n\(out)")

        }

    }
    
    public func write() {
        input.write(config: config)
        concurrentDispatchGroup.wait()
    }
    
    public func statistics() -> Statistics {
        return Statistics(gallery: self)
    }
}
