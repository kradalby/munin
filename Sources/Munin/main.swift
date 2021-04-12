import Configuration
// import Commander
// import Config
import Foundation
import Logging
import MuninKit

let log = Logger(label: "no.kradalby.Munin.main")

func main() {
  let manager = ConfigurationManager()
  manager
    .load(file: "munin.json", relativeFrom: .pwd)
    .load(.environmentVariables)
    .load(.commandLineArguments)

  let dry = manager["dry"] as? Bool ?? false
  let json = manager["json"] as? Bool ?? false

  let config = GalleryConfiguration(manager)

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
