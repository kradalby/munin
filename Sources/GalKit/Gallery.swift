//
//  Gallery.swift
//  GalPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Foundation
import Config

public struct GalleryConfiguration: Configuration {
    var name: String
    var people: [String]
    var resolutions: [Int]
    var jpegCompression: Double
    var inputPath: String
    var outputPath: String
    var fileExtentions: [String]
    
    enum CodingKeys: String, CodingKey
    {
        case name
        case people
        case resolutions
        case jpegCompression
        case inputPath
        case outputPath
        case fileExtentions
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

    }
}

public struct Gallery {
    var input: Album
    var output: Album?
    var config: GalleryConfiguration
    
    public init(config: GalleryConfiguration) {
        self.config = config
        self.input = readStateFromInputDirectory(atPath: config.inputPath, outPath: config.outputPath, name: config.name, config: config)
        if let album = readStateFromOutputDirectory(indexFileAtPath: "\(config.outputPath)/\(config.name)/index.json") {
            self.output = album
        } else {
            log.info("Could not find any output album, assuming new is to be created")
        }
    }
    
    public func write() {
        input.writeToOutputDirectory(config: config)
    }
}
