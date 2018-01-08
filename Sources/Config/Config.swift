import Foundation
import Logger

let log = Logger()

public protocol Configuration: Decodable {

}

public func readConfig<T: Configuration>(configFormat: T.Type, atPath: String) -> T {
    if let config = readAndDecodeJsonFile(configFormat, atPath: atPath) {
        return config
    }
    log.error("Could not read configuration file")
    exit(1)
}


func readAndDecodeJsonFile<T>(_ type: T.Type, atPath: String) -> T? where T : Decodable {
    let fm = FileManager()
    var isDirectory: ObjCBool = ObjCBool(false)
    let exists = fm.fileExists(atPath: atPath, isDirectory: &isDirectory)
    
    if exists && !isDirectory.boolValue {
        if let indexFile = try? Data(contentsOf: URL(fileURLWithPath: atPath)) {
            
            log.info("Decoding \(atPath)")
            let decoder = JSONDecoder()
            if #available(OSX 10.12, *) {
                decoder.dateDecodingStrategy = .iso8601
            }
            
            if let decodedData = try? decoder.decode(type, from: indexFile) {
                return decodedData
            } else {
                log.error("Could not decode \(atPath)")
            }
        } else {
            log.error("Could not read \(atPath)")
        }
    } else {
        log.error("File \(atPath) does not exist")
    }
    return nil
}
