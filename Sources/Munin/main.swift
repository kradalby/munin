import ArgumentParser
import Configuration
import Foundation
import Logging
import MuninKit
import VIPS

let log = Logger(label: "no.kradalby.Munin.main")

struct Munin: ParsableCommand {
  @Option(help: "Specify the configuration to load")
  var config = "munin.json"

  @Flag(help: "Write only JSON data, no images")
  var json = false

  @Flag(help: "Dry run")
  var dry = false

  func run() throws {
    let configPath = URL(fileURLWithPath: config)

    let manager = ConfigurationManager()
    manager
      .load(file: configPath.path, relativeFrom: .pwd)
      .load(.environmentVariables)
      .load(.commandLineArguments)

    let config = GalleryConfiguration(manager)

    let ctx = Context(config: config)

    let gallery = Gallery(ctx: ctx)

    try VIPS.start(concurrency: config.concurrency)

    if !dry {
      let start = Date()
      gallery.build(ctx: ctx, jsonOnly: json)
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

Munin.main()
