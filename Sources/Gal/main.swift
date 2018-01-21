import Foundation

import GalKit
import Logger
import Config
import Commander

var log = Logger(LogLevel.INFO)

let main = command(
    Option("config", default: "gal.json", description: "JSON based configuration file for gal"),
    Flag("dry", default: false, description: "Dry-run, do not write gallery")
) { config, dry in
    

    let config = Config.readConfig(configFormat: GalleryConfiguration.self, atPath: config)

    log = Logger(config.logLevel)

    let gallery = Gallery(config: config)
    
    if !dry {
        let start = Date()
        gallery.write()
        let end = Date()
        
        let executionTime = end.timeIntervalSince(start)
        
        log.info("Generated in: \(executionTime) seconds")
    }
    let stats = gallery.statistics().toString()
    log.info(stats)
}

main.run()





