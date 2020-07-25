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
import TSCBasic
import TSCUtility

// Create a factory which will point any newly created logs to the same file
// let fileFactory = FileLogHandlerFactory(path: "munin.log")

// Initialize the file log handler
// LoggingSystem.bootstrap(fileFactory.makeFileLogHandler)

var log = Logger(label: "no.kradalby.MuninKit")

let stateQueue = DispatchQueue(label: "no.kradalby.MuninKit.stateQueue", qos: .userInteractive)
let photoQueue = DispatchQueue(
  label: "no.kradalby.MuninKit.photoQueue", qos: .userInitiated, attributes: [.concurrent])
let photoToWriteGroup = DispatchGroup()
let photoWriteGroup = DispatchGroup()
let photoToReadGroup = DispatchGroup()

struct Timings {
  var readInputDirectory: TimeInterval?
  var readOutputDirectory: TimeInterval?
  var generateDiff: TimeInterval?
}

class State {
  let writingProgress: PercentProgressAnimation
  let readingProgress: ReadingProgressAnimation?

  var lastReadPhoto: String = ""
  var photosToWrite: Int {
    didSet {
      renderReading()
    }
  }
  var photosWritten: Int {
    didSet {
      renderWriting()
    }
  }

  init() {
    photosToWrite = 0
    photosWritten = 0

    writingProgress = PercentProgressAnimation(
      stream: TSCBasic.stdoutStream, header: "Writing images")

    if let terminal = TerminalController(stream: TSCBasic.stdoutStream) {
      readingProgress = ReadingProgressAnimation(terminal: terminal, header: "Finding images")
    } else {
      readingProgress = nil
    }
  }

  func completeRead() {
    if let progress = readingProgress {
      progress.complete(
        success: true)
    }
  }

  func resetWrite(photosWritten: Int) {
    self.photosWritten = photosWritten
  }

  func updatePhotosToWrite(name: String) {
    lastReadPhoto = name
    photosToWrite += 1
  }

  func incrementPhotosWritten() {
    photosWritten += 1
  }

  func renderReading() {
    if let progress = readingProgress {
      progress.update(
        step: photosToWrite, total: 0,
        text: "Reading: \(lastReadPhoto)")
    }
  }

  func renderWriting() {
    writingProgress.update(
      step: photosWritten, total: photosToWrite,
      text: "Writing: \(photosWritten) out of \(photosToWrite)")

    if photosToWrite == photosWritten {
      writingProgress.complete(success: true)
    }
  }
}

public struct Context {
  let config: GalleryConfiguration
  var time: Timings?
  var state: State

  public init(config: GalleryConfiguration) {
    self.config = config

    log.logLevel = .critical

    // LoggingSystem.bootstrap(StreamLogHandler.standardError)
    // time = Timings()

    state = State()
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
    photoToReadGroup.wait()
    ctx.state.completeRead()
    time.readInputDirectory = Date().timeIntervalSince(inputStart)

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
    print("Times: ", time)
  }

  public func build(ctx: Context, jsonOnly: Bool) {
    if let removed = removedDiff {
      log.info("Removing images from diff")
      removed.destroy(ctx: ctx)
    }

    if let added = addedDiff {
      log.info("Adding images from diff")
      // ctx.state.reset(photosToWrite: added.numberOfPhotos(travers: true), photosWritten: 0)
      added.write(ctx: ctx, writeJson: false, writeImage: !jsonOnly)
      // Wait for all photos to be written to disk
      photoWriteGroup.wait()
    }

    ctx.state.resetWrite(photosWritten: 0)
    let writeJsonStart = Date()
    if addedDiff == nil, removedDiff == nil {
      input.write(ctx: ctx, writeJson: true, writeImage: true)
    } else {
      // We have already changed the actual image files, so we only write json
      input.write(ctx: ctx, writeJson: true, writeImage: false)
    }

    // Wait for all photos to be written to disk
    photoWriteGroup.wait()

    let writeJsonEnd = Date()
    log.info("Images written in \(writeJsonEnd.timeIntervalSince(writeJsonStart)) seconds")

    let buildKeywordsStart = Date()
    buildKeywordsFromAlbum(album: input).forEach { $0.write(ctx: ctx) }
    buildPeopleFromAlbum(album: input).forEach { $0.write(ctx: ctx) }
    let buildKeywordsEnd = Date()
    log.info(
      "Keywords and people built in \(buildKeywordsEnd.timeIntervalSince(buildKeywordsStart)) seconds"
    )

    statistics(ctx: ctx).write(ctx: ctx)

    let locationStart = Date()
    Locations(gallery: self).write(ctx: ctx)
    let locationEnd = Date()
    log.info("Locations built in \(locationEnd.timeIntervalSince(locationStart)) seconds")
  }

  public func statistics(ctx: Context) -> Statistics {
    return Statistics(ctx: ctx, gallery: self)
  }
}
