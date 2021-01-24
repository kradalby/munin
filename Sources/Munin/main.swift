import Commander
import Config
import Foundation
import Logging
import MuninKit

let log = Logger(label: "no.kradalby.munin.main")

let main = command(
  Option("config", default: "munin.json", description: "JSON based configuration file for munin"),
  Flag(
    "dry",
    default: false,
    description: "Dry-run, do not write gallery"),
  Flag(
    "progress",
    default: true,
    description: "Show progress of finding photos and generating gallery"),
  Flag("diff", default: false, description: "Show what will be added and removed"),
  Flag(
    "json",
    default: false,
    description:
      "Write only JSON files, no images, useful for updating data with new munin features")
) { config, dry, progress, diff, json in

  var config = Config.readConfig(configFormat: GalleryConfiguration.self, atPath: config)
  config.progress = progress

  let ctx = Context(config: config)

  let gallery = Gallery(ctx: ctx)

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

main.run()
