//
//  Gallery.swift
//  GalPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Foundation
import Logging

struct Timings: Sendable {
  var readInputDirectory: TimeInterval?
  var readOutputDirectory: TimeInterval?
  var generateDiff: TimeInterval?
}

/// Shared progress-tracking state for a running gallery build.
///
/// Isolated as an `actor` so that concurrent `TaskGroup` tasks (photo reads,
/// photo writes) can safely update counters without explicit locking. All
/// public API is `async`-callable via `await`.
public actor State {
  let writingProgress: WritingProgress?
  let readingProgress: ReadingProgress?

  var lastReadPhoto: String = ""
  var photosToWrite: Int = 0
  var photosWritten: Int = 0

  init(progress: Bool) {
    writingProgress = progress ? WritingProgress(title: "Writing images") : nil
    readingProgress = progress ? ReadingProgress(header: "Finding images") : nil
  }

  func completeRead() {
    readingProgress?.complete()
  }

  func resetWrite(photosWritten: Int) {
    self.photosWritten = photosWritten
    renderWriting()
  }

  func updatePhotosToWrite(name: String) {
    lastReadPhoto = name
    photosToWrite += 1
    renderReading()
  }

  func incrementPhotosWritten() {
    photosWritten += 1
    renderWriting()
  }

  private func renderReading() {
    readingProgress?.update(count: photosToWrite, text: "Reading: \(lastReadPhoto)")
  }

  private func renderWriting() {
    guard let progress = writingProgress else { return }
    progress.update(step: photosWritten, total: photosToWrite)
    if photosToWrite == photosWritten {
      progress.complete(success: true)
    }
  }
}

/// Immutable, `Sendable` bundle of per-build dependencies passed to every
/// gallery operation.
///
/// Concurrency coordination lives outside of `Context` now: shared mutable
/// progress state is an `actor State`, and the previous `DispatchSemaphore`
/// rate-limiter has been replaced by per-call `AsyncSemaphore` instances
/// created in `Gallery.load` / `Gallery.build`.
public struct Context: Sendable {
  public let config: GalleryConfiguration
  public let state: State
  public let log: Logger

  public init(config: GalleryConfiguration) {
    self.config = config

    if config.logPath != nil {
      // TODO(FUTURES.md): implement file logging. For now the log path hint
      // upgrades the logger to MultiplexLogHandler so a future file handler
      // can be added without touching call sites.
      LoggingSystem.bootstrap { label in
        MultiplexLogHandler([
          StreamLogHandler.standardOutput(label: label)
        ])
      }
    }

    var logger = Logger(label: "no.kradalby.MuninKit")
    logger.logLevel = config.logLevel.map(stringToLogLevel) ?? .info
    self.log = logger

    self.state = State(progress: config.progress)
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

  /// All people recognised by this gallery: the `people` list from config
  /// plus everyone referenced in the `peopleFiles` JSON.
  var allPeople: Set<String> {
    combinedPeople
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
    await ctx.state.completeRead()
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

    await ctx.state.resetWrite(photosWritten: 0)
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
