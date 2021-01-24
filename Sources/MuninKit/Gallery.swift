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
  let writingProgress: PercentProgressAnimation?
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

  init(progress: Bool) {
    photosToWrite = 0
    photosWritten = 0

    writingProgress =
      progress
      ? PercentProgressAnimation(
        stream: TSCBasic.stdoutStream, header: "Writing images") : nil

    if progress, let terminal = TerminalController(stream: TSCBasic.stdoutStream) {
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
    if let progress = writingProgress {
      progress.update(
        step: photosWritten, total: photosToWrite,
        text: "Writing: \(photosWritten) out of \(photosToWrite)")

      if photosToWrite == photosWritten {
        progress.complete(success: true)
      }
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

    state = State(progress: config.progress)
  }
}

public struct GalleryConfiguration: Configuration, Decodable {
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
  public var progress: Bool
}

public struct Gallery {
  let input: Album
  let output: Album?

  let addedContent: Album?

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
    if let outputAlbum = readStateFromOutputDirectory(
      indexFileAtPath: "\(ctx.config.outputPath)/\(ctx.config.name)/index.json")
    {
      time.readOutputDirectory = Date().timeIntervalSince(outputStart)

      let diffStart = Date()
      let added = computeChangedPhotos(input: input, output: outputAlbum)
      time.generateDiff = Date().timeIntervalSince(diffStart)

      if let a = added, ctx.config.diff {
        prettyPrintAlbum(a)
      }

      // ctx.time = time

      output = outputAlbum
      addedContent = added
    } else {
      output = nil
      addedContent = nil
      log.info("Could not find any output album, assuming new is to be created")
    }
    print("Times: ", time)
  }

  public func build(ctx: Context, jsonOnly: Bool) {
    if let added = addedContent {
      log.info("Adding images from diff")
      // ctx.state.reset(photosToWrite: added.numberOfPhotos(travers: true), photosWritten: 0)
      added.write(ctx: ctx, writeJson: false, writeImage: !jsonOnly)
      // Wait for all photos to be written to disk
      photoWriteGroup.wait()
    }

    ctx.state.resetWrite(photosWritten: 0)
    let writeJsonStart = Date()
    if addedContent == nil {
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
