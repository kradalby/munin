//
//  Utils.swift
//  galPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Foundation
import Logger

let log = Logger()

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

func createOrReplaceSymlink(from: String, to: String) throws -> Void {
    let fm = FileManager()
    
    var isDirectory: ObjCBool = ObjCBool(false)
    let exists = fm.fileExists(atPath: to, isDirectory: &isDirectory)
    if exists || isDirectory.boolValue {
        log.trace("Symlink exists, removing \(to)")
        try fm.removeItem(atPath: to)
    }
    
    try fm.createSymbolicLink(at: URL(fileURLWithPath: to), withDestinationURL: URL(fileURLWithPath:from))
}

func joinPath(paths: String...) -> String {
    return paths.filter({$0 != ""}).joined(separator: "/")
}

func fileExtension(atPath: String) -> String? {
    let url = NSURL(fileURLWithPath: atPath)
    return url.pathExtension
}

func fileNameWithoutExtension(atPath: String) -> String? {
    let url = NSURL(fileURLWithPath: atPath)
    if let fileName = url.lastPathComponent, let fileExtension = url.pathExtension {
        return fileName.replacingOccurrences(of: ".\(fileExtension)", with: "")
    }
    return nil
}

func resizeImage(imageSource: CGImageSource, maxResolution: Int, compression: CGFloat) -> Data? {
    // get source properties so we retain metadata (EXIF) for the downsized image
    if var metaData = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
        let width = metaData[kCGImagePropertyPixelWidth as String] as? Int,
        let height = metaData[kCGImagePropertyPixelHeight as String] as? Int {
        
        let srcMaxResolution = max(width, height)
        
        // if max resolution is exceeded, then scale image to new resolution
        if srcMaxResolution >= maxResolution {
            let scaleOptions  = [ kCGImageSourceThumbnailMaxPixelSize as String : maxResolution,
                                  kCGImageSourceCreateThumbnailFromImageAlways as String : true] as [String: Any]
            
            if let scaledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, scaleOptions as CFDictionary) {
                
                // add compression ratio to desitnation options
                metaData[kCGImageDestinationLossyCompressionQuality as String] = compression
                
                //create new jpeg
                let newImageData = NSMutableData()
                if let cgImageDestination = CGImageDestinationCreateWithData(newImageData, kUTTypeJPEG, 1, nil) {
                    
                    CGImageDestinationAddImage(cgImageDestination, scaledImage, metaData as CFDictionary)
                    CGImageDestinationFinalize(cgImageDestination)
                    
                    return newImageData as Data
                }
            }
        }
    }
    return nil
}
