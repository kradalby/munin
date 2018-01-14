import Foundation

import GalKit
import Logger
import Config

let log = Logger()


//let file = FileDestination()
//file.logFileURL = URL(fileURLWithPath: "/tmp/g.log")
//file.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $C$L$c: $M"
//file.minLevel = log.Level.info
//log.addDestination(file)



//let state = readStateFromInputDirectory(atPath: basePath, outPath: "out", name: "sample")
//log.debug("\(state)")
//let outDirState = readStateFromOutputDirectory(indexFileAtPath: "out/sample/index.json")!
//log.debug("\(outDirState)")
//// writeStateToOutputDirectory(state: state)
//
//log.debug("\("\(state)" == "\(outDirState)")")

let config = Config.readConfig(configFormat: GalleryConfiguration.self, atPath: "config.json")
let gallery = Gallery(config: config)

let stats = gallery.statistics().toString()
log.info(stats)

//let start = Date()
//gallery.write()
//let end = Date()
//
//let executionTime = end.timeIntervalSince(start)
//
//log.info("in: \(executionTime) seconds")

