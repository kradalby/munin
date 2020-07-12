//
//  Gallery.swift
//  GalPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Config
import Dispatch
import Foundation
import Logger
import Progress
import Queuer

// let concurrentQueue = OperationQueue()
// // DispatchQueue(
// //   label: "no.kradalby.gal.Gallery",
// //   attributes: .concurrent
// // )

// let concurrentPhotoEncodeGroup = DispatchGroup()
// // let concurrentPhotoReadJSONGroup = DispatchGroup()
// let concurrentPhotoReadDirectoryGroup = DispatchGroup()

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
  public var diff: Bool
  var concurrency: Int

  var queue: Queuer

  enum CodingKeys: String, CodingKey {
    case name
    case people
    case resolutions
    case jpegCompression
    case inputPath
    case outputPath
    case fileExtentions
    case logLevel
    case diff
    case concurrency
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    name = try values.decode(String.self, forKey: .name)
    people = try values.decode([String].self, forKey: .people)
    resolutions = try values.decode([Int].self, forKey: .resolutions)
    jpegCompression = try values.decode(Double.self, forKey: .jpegCompression)
    inputPath = try values.decode(String.self, forKey: .inputPath)
    outputPath = try values.decode(String.self, forKey: .outputPath)
    fileExtentions = try values.decode([String].self, forKey: .fileExtentions)
    logLevel = try values.decode(Int.self, forKey: .logLevel)
    diff = try values.decode(Bool.self, forKey: .diff)
    concurrency = try values.decode(Int.self, forKey: .concurrency)

    if concurrency > 0 {
      log.info("Setting concurrency to \(concurrency)")
      self.queue = Queuer(
        name: "MuninQueue", maxConcurrentOperationCount: concurrency, qualityOfService: .default)
    }
    self.queue = Queuer(
      name: "MuninQueue", maxConcurrentOperationCount: Int.max, qualityOfService: .default)
  }
}

public struct Gallery {
  let config: GalleryConfiguration

  let input: Album
  let output: Album?

  let addedDiff: Album?
  let removedDiff: Album?

  // swiftlint:disable function_body_length
  public init(config: GalleryConfiguration) {

    self.config = config

    log = Logger(config.logLevel)

    // read input directory
    let inputStart = Date()
    let input = readStateFromInputDirectory(
      atPath: config.inputPath,
      outPath: config.outputPath,
      name: config.name,
      parents: [],
      config: config
    )
    let inputEnd = Date()
    // TODO: Determine of this should be log or print
    print("Input directory read in \(inputEnd.timeIntervalSince(inputStart)) seconds")

    let outputStart = Date()
    if let album = readStateFromOutputDirectory(
      indexFileAtPath: "\(config.outputPath)/\(config.name)/index.json")
    {
      let output = album
      let outputEnd = Date()
      // TODO: Determine of this should be log or print
      print("Output directory read in \(outputEnd.timeIntervalSince(outputStart)) seconds")

      log.debug("Input album differs from output album: \(input != output)")
      //        log.debug("Input: \n\(self.input)")
      //        if let out = self.output {
      //            log.debug("Output: \n\(out)")
      //        }
      let diffStart = Date()

      let (added, removed) = diff(new: input, old: output)

      let diffEnd = Date()

      if config.diff {
        if let unwrappedAdded = added, let unwrappedRemoved = removed {
          print("")
          print("")
          print("Added:".green)
          //                    prettyPrintAlbum(unwrappedAdded)
          prettyPrintAdded(unwrappedAdded)
          print("")
          print("")
          print("Removed:".red)
          //                    prettyPrintAlbum(unwrappedRemoved)
          prettyPrintRemoved(unwrappedRemoved)
          print("")
        }
      }
      // TODO: Determine of this should be log or print
      print("Diff generated in: \(diffEnd.timeIntervalSince(diffStart)) seconds")

      self.output = output
      addedDiff = added
      removedDiff = removed
    } else {
      output = nil
      addedDiff = nil
      removedDiff = nil
      log.info("Could not find any output album, assuming new is to be created")
    }

    self.input = input
  }

  public func build(jsonOnly: Bool) {
    if let removed = removedDiff {
      log.info("Removing images from diff")
      let removeStart = Date()
      removed.destroy(config: config)
      let removeEnd = Date()
      print("Photos removed in \(removeEnd.timeIntervalSince(removeStart)) seconds")
    }

    if let added = addedDiff {
      log.info("Adding images from diff")
      let addStart = Date()
      added.write(config: config, writeJson: false, writeImage: !jsonOnly)
      // concurrentPhotoEncodeGroup.wait()
      config.queue.waitUntilAllOperationsAreFinished()
      let addEnd = Date()
      print("Photos added in \(addEnd.timeIntervalSince(addStart)) seconds")
    }

    log.info("----------------------------------------------------------------------------")

    // We have already changed the actual image files, so we only write json
    let writeJsonStart = Date()
    if addedDiff == nil, removedDiff == nil {
      input.write(config: config, writeJson: true, writeImage: true)
    } else {
      input.write(config: config, writeJson: true, writeImage: false)
    }
    let queueBuiltEnd = Date()
    print(
      "Operations queue built in \(queueBuiltEnd.timeIntervalSince(writeJsonStart)) seconds, with \(config.queue.operationCount) items"
    )

    // concurrentPhotoEncodeGroup.wait()

    let totalOperations = config.queue.operationCount
    var bar = ProgressBar(
      count: totalOperations,
      configuration: [ProgressPercent(), ProgressBarLine(barLength: 60), ProgressIndex()])

    while !config.queue.operations.isEmpty {
      bar.setValue(totalOperations - config.queue.operationCount)
    }

    config.queue.waitUntilAllOperationsAreFinished()
    bar.setValue(totalOperations)

    let writeJsonEnd = Date()
    print("Images written in \(writeJsonEnd.timeIntervalSince(writeJsonStart)) seconds")

    let buildKeywordsStart = Date()
    buildKeywordsFromAlbum(album: input).forEach { $0.write(config: config) }
    buildPeopleFromAlbum(album: input).forEach { $0.write(config: config) }
    let buildKeywordsEnd = Date()
    print(
      "Keywords and people built in \(buildKeywordsEnd.timeIntervalSince(buildKeywordsStart)) seconds"
    )

    statistics().write(config: config)

    let locationStart = Date()
    Locations(gallery: self).write(config: config)
    let locationEnd = Date()
    print("Locations built in \(locationEnd.timeIntervalSince(locationStart)) seconds")
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

  let changedAlbums = pairChangedAlbums(
    newAlbums: Array(onlyNewAlbums), oldAlbums: Array(onlyOldAlbums))

  for changed in changedAlbums {
    if let newChangedAlbum = changed.0,
      let oldChangedAlbum = changed.1
    {
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
      for old in oldAlbums where new.name == old.name {
        pairs.append((new, old))
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
  for item in albums where album.name == item.name {
    return true
  }
  return false
}
