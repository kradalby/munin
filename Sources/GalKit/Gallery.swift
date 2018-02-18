//
//  Gallery.swift
//  GalPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Foundation
import Config
import Logger

let concurrentQueue =
    DispatchQueue(
        label: "no.kradalby.gal.Gallery",
        attributes: .concurrent)

let concurrentPhotoEncodeGroup = DispatchGroup()
//let concurrentPhotoReadJSONGroup = DispatchGroup()
let concurrentPhotoReadDirectoryGroup = DispatchGroup()



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
//        log.debug("Input: \n\(self.input)")
//        if let out = self.output {
//            log.debug("Output: \n\(out)")
//        }
        
        let diffStart = Date()
        if let output = self.output {
            let (added, removed) = diff(new: self.input, old: output)
            if let unwrappedAdded = added, let unwrappedRemoved = removed {
                log.debug("Added:")
                prettyPrintAlbum(unwrappedAdded)
                log.debug("")
                log.debug("")
                log.debug("Removed:")
                prettyPrintAlbum(unwrappedRemoved)
                log.debug("")
            }
        }
        let diffEnd = Date()
        log.debug("Diff generated in: \(diffEnd.timeIntervalSince(diffStart)) seconds")


    }
    
    public func write() {
        input.write(config: config)
        concurrentPhotoEncodeGroup.wait()
        self.statistics().write(config: self.config)
    }
    
    public func statistics() -> Statistics {
        return Statistics(gallery: self)
    }
}

func diff(new: Album, old: Album) -> (Album?, Album?) {
    if new == old {
        return (nil, nil)
    }
    
    var removed = new.copyWithoutChildren()
    var added = new.copyWithoutChildren()
    
    removed.photos = old.photos.subtracting(new.photos)
    added.photos = new.photos.subtracting(old.photos)
    
    log.debug("Removed photos: \(removed.photos)")
    log.debug("Added photos: \(added.photos)")
    
    // Not changed
    let _ = new.albums.intersection(old.albums)
    let onlyNewAlbums = new.albums.subtracting(old.albums)
    let onlyOldAlbums = old.albums.subtracting(new.albums)
    
    let changedAlbums = pairChangedAlbums(newAlbums: Array(onlyNewAlbums), oldAlbums: Array(onlyOldAlbums))
    
    for changed in changedAlbums {
        if let newChangedAlbum = changed.0,
            let oldChangedAlbum = changed.1 {
            let (addedChild, removedChild) = diff(new: newChangedAlbum, old: oldChangedAlbum)
            
            if let child = addedChild {
                added.albums.insert(child)
            }
            
            if let child = removedChild {
                removed.albums.insert(child)
            }
        } else if let newChangedAlbum = changed.0 {
            added.albums.insert(newChangedAlbum)
        } else if let oldChangedAlbum = changed.1 {
            removed.albums.insert(oldChangedAlbum)
        }
    }
    
    return (added, removed)
}

func pairChangedAlbums(newAlbums: [Album], oldAlbums: [Album]) -> ([(Album?, Album?)]) {
    var pairs: [(Album?, Album?)] = []
    
    for new in newAlbums {
        if isAlbumInListByName(album: new, albums: oldAlbums) {
            for old in oldAlbums {
                if new.name == old.name {
                    pairs.append((new, old))
                }
            }
        } else {
            pairs.append((new, nil))
        }
    }
    for old in oldAlbums {
        if !isAlbumInListByName(album: old, albums: newAlbums) {
            pairs.append((nil, old))
        }
    }
    
    return pairs
}

func isAlbumInListByName(album: Album, albums: [Album]) -> Bool {
    for item in albums {
        if album.name == item.name {
            return true
        }
    }
    return false
}
