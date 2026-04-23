//
//  Gallery.swift
//  GalPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Dispatch
import Foundation
import Logging

let stateQueue = DispatchQueue(label: "no.kradalby.MuninKit.stateQueue", qos: .userInteractive)
let photoQueue = DispatchQueue(
  label: "no.kradalby.MuninKit.photoQueue", qos: .userInitiated, attributes: [.concurrent])
let photoToWriteGroup = DispatchGroup()
let photoWriteGroup = DispatchGroup()
let photoToReadGroup = DispatchGroup()

struct Timings: Sendable {
  var readInputDirectory: TimeInterval?
  var readOutputDirectory: TimeInterval?
  var generateDiff: TimeInterval?
}

// @unchecked Sendable: temporary. State mutates via GCD queue serialization in
// the current code. Scheduled to become a proper `actor State` in commit 6 of
// the MUNIN_MODERNISE_PLAN.md sequence.
final class State: @unchecked Sendable {
  let writingProgress: WritingProgress?
  let readingProgress: ReadingProgress?

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

    writingProgress = progress ? WritingProgress(title: "Writing images") : nil
    readingProgress = progress ? ReadingProgress(header: "Finding images") : nil
  }

  func completeRead() {
    readingProgress?.complete()
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
    readingProgress?.update(count: photosToWrite, text: "Reading: \(lastReadPhoto)")
  }

  func renderWriting() {
    guard let progress = writingProgress else { return }
    progress.update(step: photosWritten, total: photosToWrite)
    if photosToWrite == photosWritten {
      progress.complete(success: true)
    }
  }
}

// @unchecked Sendable: temporary. Context contains a mutable Logger, a
// DispatchSemaphore, and a State class whose mutations are serialized through
// `stateQueue`. Scheduled to become truly Sendable once State is an actor and
// rate-limiting moves to an AsyncSemaphore (commits 6–8).
public struct Context: @unchecked Sendable {
  let config: GalleryConfiguration
  var time: Timings?
  var state: State
  var log: Logger
  let sema: DispatchSemaphore

  public init(config: GalleryConfiguration) {
    self.config = config

    if let _ = config.logPath {
      // do {
      // let fileLogger = try FileLogging(to: URL(fileURLWithPath: logPath))

      LoggingSystem.bootstrap { label in
        let handlers: [LogHandler] = [
          // FileLogHandler(label: label, fileLogger: fileLogger),
          StreamLogHandler.standardOutput(label: label)
        ]
        return MultiplexLogHandler(handlers)
      }
      // } catch {
      //   print("Failed to set up log file, stdout only")
      // }
    }

    log = Logger(label: "no.kradalby.MuninKit")
    if let logLevel = config.logLevel {
      log.logLevel = stringToLogLevel(logLevel)
    } else {
      log.logLevel = .info
    }

    // https://www.vadimbulavin.com/grand-central-dispatch-in-swift/#limiting-work-in-progress
    sema = DispatchSemaphore(value: config.concurrency)

    state = State(progress: config.progress)
  }
}

public struct GalleryConfiguration: Sendable {
  let name: String
  let people: [String]
  let peopleFiles: [String]
  let resolutions: [Int]
  let jpegCompression: Double
  let inputPath: String
  let outputPath: String
  let fileExtensions: [String]
  public let concurrency: Int

  let logPath: String?
  let logLevel: String?
  let diff: Bool
  let progress: Bool

  let combinedPeople: Set<String>

  public init(
    _ manager: ConfigurationManager
  ) {
    name = manager["name"] as? String ?? "root"
    people = manager["people"] as? [String] ?? []
    peopleFiles = manager["peopleFiles"] as? [String] ?? []
    resolutions = manager["resolutions"] as? [Int] ?? [1600, 1200, 992, 768, 576, 340, 220, 180]
    jpegCompression = manager["jpegCompression"] as? Double ?? 1
    inputPath = manager["sourceFolder"] as? String ?? ""
    outputPath = manager["targetFolder"] as? String ?? ""
    fileExtensions = manager["fileExtensions"] as? [String] ?? ["jpg", "jpeg", "JPG", "JPEG"]
    concurrency = manager["concurrency"] as? Int ?? ProcessInfo.processInfo.processorCount
    logPath = manager["logPath"] as? String
    logLevel = manager["logLevel"] as? String
    diff = manager["diff"] as? Bool ?? false
    progress = manager["progress"] as? Bool ?? true

    let peopleFromFiles: [[String]] = peopleFiles.compactMap { file in
      if let peopleFile = readAndDecodeJsonFile(PeopleFile.self, atPath: file) {
        return peopleFile.people
      }
      return nil
    }
    self.combinedPeople = Set(people).union(peopleFromFiles.flatMap { $0 })
  }

  func allPeople() -> Set<String> {
    return combinedPeople
  }
}

struct PeopleFile: Decodable, Sendable {
  let people: [String]
}

public struct Gallery: Sendable {
  var input: Album
  var output: Album?

  mutating func setInput(_ input: Album) {
    self.input = input
  }

  mutating func setOutput(_ output: Album) {
    self.output = output
  }

  let changedContent: Album?

  private init(input: Album, output: Album?, changedContent: Album?) {
    self.input = input
    self.output = output
    self.changedContent = changedContent
  }

  /// Load a gallery by reading the configured input directory, optionally
  /// diffing it against an existing output directory.
  ///
  /// - Parameter ctx: Shared configuration/state/log for the build.
  /// - Returns: A `Gallery` with its input tree populated and, if an
  ///   existing output directory was found, its `output` and `changedContent`
  ///   fields set.
  public static func load(ctx: Context) async throws -> Gallery {
    var time = Timings()

    let inputStart = Date()
    let input = try await readStateFromInputDirectory(
      ctx: ctx,
      atPath: ctx.config.inputPath,
      outPath: ctx.config.outputPath,
      name: ctx.config.name,
      parents: []
    )
    ctx.state.completeRead()
    time.readInputDirectory = Date().timeIntervalSince(inputStart)

    ctx.log.debug(
      "Looking for output directory at \(ctx.config.outputPath)/\(ctx.config.name)/index.json")
    let outputStart = Date()
    let outputAlbum = readStateFromOutputDirectory(
      indexFileAtPath: "\(ctx.config.outputPath)/\(ctx.config.name)/index.json")

    var output: Album? = nil
    var changedContent: Album? = nil

    if let outputAlbum {
      time.readOutputDirectory = Date().timeIntervalSince(outputStart)
      ctx.log.debug("Output directory read from disk")

      ctx.log.debug("Creating diff between input and output album")
      let diffStart = Date()
      let changed = computeChangedPhotos(input: input, output: outputAlbum)
      time.generateDiff = Date().timeIntervalSince(diffStart)

      if let changed, ctx.config.diff {
        prettyPrintAdded(changed)
      }

      output = outputAlbum
      changedContent = changed
    } else {
      ctx.log.info("Could not find any output album, assuming new is to be created")
    }
    print("Times: ", time)

    return Gallery(input: input, output: output, changedContent: changedContent)
  }

  public func build(ctx: Context, jsonOnly: Bool) async throws {
    let sem = AsyncSemaphore(value: max(ctx.config.concurrency, 1))

    if let changed = changedContent {
      ctx.log.info("Updating changed photos, resizing and writing images to disk")
      try await changed.write(
        ctx: ctx, writeJson: false, writeImage: !jsonOnly, sem: sem)
    }

    ctx.state.resetWrite(photosWritten: 0)
    let writeJsonStart = Date()
    if output == nil {
      ctx.log.info("First run, creating images and metadata")
      try await input.write(ctx: ctx, writeJson: true, writeImage: true, sem: sem)
    } else {
      ctx.log.info("Updating changed photos, writing JSON metadata to disk")
      // We have already changed the actual image files, so we only write json
      try await input.write(ctx: ctx, writeJson: true, writeImage: false, sem: sem)
    }

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
