import Foundation

import MuninKit
import Logger
import Config
import Commander

var log = Logger(LogLevel.INFO)

let main = command(
    Option("config", default: "munin.json", description: "JSON based configuration file for munin"),
    Flag("dry", default: false, description: "Dry-run, do not write gallery"),
//    Flag("diff", default: false, description: "Show what will be added and removed"),
    Flag("json", default: false, description: "Write only JSON files, no images, useful for updating data with new munin features")
) { config, dry, json in

    let config = Config.readConfig(configFormat: GalleryConfiguration.self, atPath: config)

    log = Logger(config.logLevel)

    let gallery = Gallery(config: config)

    if !dry {
        let start = Date()
        gallery.build(jsonOnly: json)
        let end = Date()

        let executionTime = end.timeIntervalSince(start)

        // TODO: Determine of this should be log or print
        print("Generated in: \(executionTime) seconds")
    }
    let stats = gallery.statistics().toString()
    // TODO: Determine of this should be log or print
    print(stats)
}

main.run()
