import ArgumentParser
import Foundation
import Logging
import MuninKit
import VIPS

let log = Logger(label: "no.kradalby.Munin.main")

@main
struct Munin: AsyncParsableCommand {
  @Option(help: "Specify the configuration to load")
  var config = "munin.json"

  @Flag(help: "Write only JSON data, no images")
  var json = false

  @Flag(help: "Dry run")
  var dry = false

  func run() async throws {
    let configPath = URL(fileURLWithPath: config)

    let manager = ConfigurationManager()
    manager
      .load(file: configPath.path, relativeFrom: .pwd)
      .load(.environmentVariables)
      .load(.commandLineArguments)

    let galleryConfig = GalleryConfiguration(manager)

    // VIPS must be initialized once per process before any VIPSImage use.
    try VIPS.start(concurrency: galleryConfig.concurrency)

    let ctx = Context(config: galleryConfig)
    let gallery = try await Gallery.load(ctx: ctx)

    if !dry {
      let start = Date()
      try await gallery.build(ctx: ctx, jsonOnly: json)
      let end = Date()
      let executionTime = end.timeIntervalSince(start)

      let startClean = Date()
      gallery.clean(ctx: ctx)
      let endClean = Date()
      let executionTimeClean = endClean.timeIntervalSince(startClean)

      print("Generated in: \(executionTime) seconds")
      print("Cleaned in: \(executionTimeClean) seconds")
    }
    let stats = gallery.statistics(ctx: ctx).toString()
    print(stats)
  }
}
