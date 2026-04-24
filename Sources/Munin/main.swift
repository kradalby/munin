import ArgumentParser
import Foundation
import Logging
import MuninKit

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

    // VIPS must be initialised once per process before any VIPSImage use.
    // `VIPSBootstrap.start` is idempotent and documents the no-shutdown
    // policy we rely on for process-exit safety.
    try VIPSBootstrap.start(concurrency: galleryConfig.concurrency)

    let ctx = Context(config: galleryConfig)
    let gallery = try await Gallery.load(ctx: ctx)

    var report = BuildReport()
    if !dry {
      let start = Date()
      report = try await gallery.build(ctx: ctx, jsonOnly: json)
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

    if report.hasFailures {
      print("\n\(report.failures.count) photo(s) failed to write:")
      for failure in report.failures {
        print("  - \(failure)")
      }
      throw ExitCode.failure
    }
  }
}
