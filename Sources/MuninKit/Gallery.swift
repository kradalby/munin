//
//  Gallery.swift
//  GalPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Config
import Dispatch
import FileLogging
import Foundation
import Logging
import TSCBasic
import TSCUtility

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
  var log: Logger

  public init(config: GalleryConfiguration) {
    self.config = config

    if let logPath = config.logPath {
      do {
        let fileLogger = try FileLogging(to: URL(fileURLWithPath: logPath))

        LoggingSystem.bootstrap { label in
          let handlers: [LogHandler] = [
            FileLogHandler(label: label, fileLogger: fileLogger),
            StreamLogHandler.standardOutput(label: label),
          ]
          return MultiplexLogHandler(handlers)
        }
      } catch {
        print("Failed to set up log file, stdout only")
      }
    }

    log = Logger(label: "no.kradalby.MuninKit")
    if let logLevel = config.logLevel {
      log.logLevel = stringToLogLevel(logLevel)
    } else {
      log.logLevel = .info
    }

    state = State(progress: config.progress)
  }
}

public struct GalleryConfiguration: Configuration, Decodable {
  var name: String
  var people: [String]
  var peopleFiles: [String]
  var resolutions: [Int]
  var jpegCompression: Double
  var inputPath: String
  var outputPath: String
  var fileExtensions: [String]
  var concurrency: Int

  var logPath: String?
  var logLevel: String?
  var diff: Bool
  var progress: Bool

  public mutating func initHook() {
    combinePeople()
  }

  mutating func setLogLevel(_ logLevel: String) {
    self.logLevel = logLevel
  }

  public mutating func setDiff(_ diff: Bool) {
    self.diff = diff
  }

  public mutating func setProgress(_ progress: Bool) {
    self.progress = progress
  }

  enum CodingKeys: String, CodingKey {
    case name, people, peopleFiles, resolutions, jpegCompression, inputPath, outputPath,
      fileExtensions, logPath, logLevel, diff, concurrency, progress
  }

  var combinedPeople: Set<String> = []
  mutating func combinePeople() {
    let peopleFromFiles: [[String]] = peopleFiles.compactMap { file in
      if let peopleFile = readAndDecodeJsonFile(PeopleFile.self, atPath: file) {
        return peopleFile.people
      }
      return nil
    }
    combinedPeople = Set(people).union(peopleFromFiles.flatMap { $0 })
  }

  func allPeople() -> Set<String> {
    return combinedPeople
  }
}

struct PeopleFile: Decodable {
  let people: [String]
}

public struct Gallery {
  var input: Album
  var output: Album?

  mutating func setInput(_ input: Album) {
    self.input = input
  }

  mutating func setOutput(_ output: Album) {
    self.output = output
  }

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
        prettyPrintAdded(a)
      }

      // ctx.time = time

      output = outputAlbum
      addedContent = added
    } else {
      output = nil
      addedContent = nil
      ctx.log.info("Could not find any output album, assuming new is to be created")
    }
    print("Times: ", time)
  }

  public func build(ctx: Context, jsonOnly: Bool) {
    if let added = addedContent {
      ctx.log.info("Adding new photos")
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
    ctx.log.info("Images written in \(writeJsonEnd.timeIntervalSince(writeJsonStart)) seconds")

    let buildKeywordsStart = Date()
    buildKeywordsFromAlbum(album: input).forEach { $0.write(ctx: ctx) }
    buildPeopleFromAlbum(album: input).forEach { $0.write(ctx: ctx) }
    let buildKeywordsEnd = Date()
    ctx.log.info(
      "Keywords and people built in \(buildKeywordsEnd.timeIntervalSince(buildKeywordsStart)) seconds"
    )

    statistics(ctx: ctx).write(ctx: ctx)

    let locationStart = Date()
    Locations(gallery: self).write(ctx: ctx)
    let locationEnd = Date()
    ctx.log.info("Locations built in \(locationEnd.timeIntervalSince(locationStart)) seconds")
  }

  public func clean(ctx: Context) {
    input.clean(ctx: ctx)
  }

  public func statistics(ctx: Context) -> Statistics {
    return Statistics(ctx: ctx, gallery: self)
  }
}
