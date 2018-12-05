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

    enum CodingKeys: String, CodingKey {
        case name
        case people
        case resolutions
        case jpegCompression
        case inputPath
        case outputPath
        case fileExtentions
        case logLevel
    }

    public init(from decoder: Decoder) throws {
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
    let config: GalleryConfiguration

    let input: Album
    let output: Album?

    let addedDiff: Album?
    let removedDiff: Album?

    public init(config: GalleryConfiguration) {
        self.config = config

        log = Logger(config.logLevel)

        // read input directory
        let inputStart = Date()
        let input = readStateFromInputDirectory(atPath: config.inputPath, outPath: config.outputPath, name: config.name, parents: [], config: config)
        let inputEnd = Date()
        // TODO: Determine of this should be log or print
        print("Input directory read in \(inputEnd.timeIntervalSince(inputStart)) seconds")

        let outputStart = Date()
        if let album = readStateFromOutputDirectory(indexFileAtPath: "\(config.outputPath)/\(config.name)/index.json") {
            let output = album
            let outputEnd = Date()
            log.debug("Output directory read in \(outputEnd.timeIntervalSince(outputStart)) seconds")

            log.debug("Input album differs from output album: \(input != output)")
            //        log.debug("Input: \n\(self.input)")
            //        if let out = self.output {
            //            log.debug("Output: \n\(out)")
            //        }
            let diffStart = Date()

                let (added, removed) = diff(new: input, old: output)
                if let unwrappedAdded = added, let unwrappedRemoved = removed {
                    log.debug("Added:")
                    prettyPrintAlbum(unwrappedAdded)
                    log.debug("")
                    log.debug("")
                    log.debug("Removed:")
                    prettyPrintAlbum(unwrappedRemoved)
                    log.debug("")
                }

            let diffEnd = Date()
            log.debug("Diff generated in: \(diffEnd.timeIntervalSince(diffStart)) seconds")

            self.output = output
            self.addedDiff = added
            self.removedDiff = removed
        } else {
            self.output = nil
            self.addedDiff = nil
            self.removedDiff = nil
            log.info("Could not find any output album, assuming new is to be created")
        }

        self.input = input

    }

    public func build(jsonOnly: Bool) {
        if let removed = self.removedDiff {
            log.info("Removing images from diff")
            removed.destroy(config: config)
        }
        
        if let added = self.addedDiff {
            log.info("Adding images from diff")
            added.write(config: config, writeJson: false, writeImage: !jsonOnly)
            concurrentPhotoEncodeGroup.wait()
        }

        log.info("----------------------------------------------------------------------------")
        
        // We have already changed the actual image files, so we only write json
        if self.addedDiff == nil && self.removedDiff == nil {
            self.input.write(config: config, writeJson: true, writeImage: true)

        } else {
            self.input.write(config: config, writeJson: true, writeImage: false)
        }
        concurrentPhotoEncodeGroup.wait()

        buildKeywordsFromAlbum(album: self.input).forEach({$0.write(config: config)})
        buildPeopleFromAlbum(album: self.input).forEach({$0.write(config: config)})

        self.statistics().write(config: self.config)
        Locations(gallery: self).write(config: self.config)
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

    // Not changed
    _ = new.albums.intersection(old.albums)
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
