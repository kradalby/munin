//
//  Gallery.swift
//  GalPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Config
import Dispatch
// import FileLogging
import Foundation
import Logging
import Queuer
import TSCBasic
import TSCUtility

// Create a factory which will point any newly created logs to the same file
// let fileFactory = FileLogHandlerFactory(path: "munin.log")

// Initialize the file log handler
// LoggingSystem.bootstrap(fileFactory.makeFileLogHandler)

let log = Logger(label: "no.kradalby.MuninKit")

// let concurrentQueue = OperationQueue()
// // DispatchQueue(
// //   label: "no.kradalby.gal.Gallery",
// //   attributes: .concurrent
// // )

// let concurrentPhotoEncodeGroup = DispatchGroup()
// // let concurrentPhotoReadJSONGroup = DispatchGroup()
// let concurrentPhotoReadDirectoryGroup = DispatchGroup()

struct Timings {
  var readInputDirectory: TimeInterval?
  var readOutputDirectory: TimeInterval?
  var generateDiff: TimeInterval?
}

struct Queues {
  var write: Queuer
  var read: Queuer
}

public struct Context {
  let config: GalleryConfiguration
  var progress: Any?
  var queues: Queues
  var time: Timings?

  public init(config: GalleryConfiguration) {
    self.config = config

    // LoggingSystem.bootstrap(StreamLogHandler.standardError)
    // time = Timings()

    let write =
      config.concurrency > 0
      ? Queuer(
        name: "write", maxConcurrentOperationCount: config.concurrency,
        qualityOfService: .default)
      : Queuer(
        name: "write", maxConcurrentOperationCount: Int.max, qualityOfService: .default)
    let read = Queuer(
      name: "read", maxConcurrentOperationCount: 1, qualityOfService: .default)

    queues = Queues(
      write: write, read: read)

  }
}

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
  }
}

public struct Gallery {
  let input: Album
  let output: Album?

  let addedDiff: Album?
  let removedDiff: Album?

  // swiftlint:disable function_body_length
  public init(ctx: Context) {
    var time = Timings()

    // read input directory
    let inputStart = Date()
    input = readStateFromInputDirectory(
      ctx: ctx,
      atPath: ctx.config.inputPath,
      outPath: ctx.config.outputPath,
      name: ctx.config.name,
      parents: []
    )
    time.readInputDirectory = Date().timeIntervalSince(inputStart)
    print(ctx.queues.read.operationCount)
    print(ctx.queues.read.operations)
    ctx.queues.read.waitUntilAllOperationsAreFinished()

    let outputStart = Date()
    if let album = readStateFromOutputDirectory(
      indexFileAtPath: "\(ctx.config.outputPath)/\(ctx.config.name)/index.json")
    {
      time.readOutputDirectory = Date().timeIntervalSince(outputStart)

      let diffStart = Date()
      let (added, removed) = diff(new: input, old: album)
      time.generateDiff = Date().timeIntervalSince(diffStart)

      // if config.diff {e
      //   print(prettyPrintDiff(added, removed))
      // }

      // ctx.time = time

      output = album
      addedDiff = added
      removedDiff = removed
    } else {
      output = nil
      addedDiff = nil
      removedDiff = nil
      log.info("Could not find any output album, assuming new is to be created")
    }
  }

  public func build(ctx: Context, jsonOnly: Bool) {
    if let removed = removedDiff {
      log.info("Removing images from diff")
      let removeStart = Date()
      removed.destroy(ctx: ctx)
      let removeEnd = Date()
      print("Photos removed in \(removeEnd.timeIntervalSince(removeStart)) seconds")
    }

    if let added = addedDiff {
      log.info("Adding images from diff")
      let addStart = Date()
      added.write(ctx: ctx, writeJson: false, writeImage: !jsonOnly)
      // concurrentPhotoEncodeGroup.wait()
      ctx.queues.write.waitUntilAllOperationsAreFinished()
      let addEnd = Date()
      print("Photos added in \(addEnd.timeIntervalSince(addStart)) seconds")
    }

    // We have already changed the actual image files, so we only write json
    let writeJsonStart = Date()
    if addedDiff == nil, removedDiff == nil {
      input.write(ctx: ctx, writeJson: true, writeImage: true)
    } else {
      input.write(ctx: ctx, writeJson: true, writeImage: false)
    }
    let queueBuiltEnd = Date()
    print(
      "Operations queue built in \(queueBuiltEnd.timeIntervalSince(writeJsonStart)) seconds, with \(ctx.queues.write.operationCount) items"
    )

    // concurrentPhotoEncodeGroup.wait()

    let totalOperations = ctx.queues.write.operationCount

    let bar = PercentProgressAnimation(stream: TSCBasic.stdoutStream, header: "Writing images")

    while !ctx.queues.write.operations.isEmpty {
      let executionCount = ctx.queues.write.operations.filter({ $0.isExecuting }).count
      bar.update(
        step: totalOperations - ctx.queues.write.operationCount, total: totalOperations,
        text: "Left: \(ctx.queues.write.operationCount), parallel: \(executionCount)")
      usleep(
        300000  // Sleep
      )
    }

    ctx.queues.write.waitUntilAllOperationsAreFinished()
    bar.complete(success: ctx.queues.write.operations.isEmpty)

    let writeJsonEnd = Date()
    print("Images written in \(writeJsonEnd.timeIntervalSince(writeJsonStart)) seconds")

    let buildKeywordsStart = Date()
    buildKeywordsFromAlbum(album: input).forEach { $0.write(ctx: ctx) }
    buildPeopleFromAlbum(album: input).forEach { $0.write(ctx: ctx) }
    let buildKeywordsEnd = Date()
    print(
      "Keywords and people built in \(buildKeywordsEnd.timeIntervalSince(buildKeywordsStart)) seconds"
    )

    statistics(ctx: ctx).write(ctx: ctx)

    let locationStart = Date()
    Locations(gallery: self).write(ctx: ctx)
    let locationEnd = Date()
    print("Locations built in \(locationEnd.timeIntervalSince(locationStart)) seconds")
  }

  public func statistics(ctx: Context) -> Statistics {
    return Statistics(ctx: ctx, gallery: self)
  }
}

func prettyPrintDiff(added: Album?, removed: Album?) -> String {
  var str = ""
  if let a = added {
    let astr = """

      Added:
      \(prettyPrintAdded(a))

      """

    str = str + astr
  }
  if let r = removed {
    let rstr = """

      Removed:
      \(prettyPrintRemoved(r))

      """

    str = str + rstr
  }
  return str
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
