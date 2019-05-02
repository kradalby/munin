//
//  Utils.swift
//  galPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Foundation

func readAndDecodeJsonFile<T>(_ type: T.Type, atPath: String) -> T? where T: Decodable {
    let fileManager = FileManager()
    var isDirectory: ObjCBool = ObjCBool(false)
    let exists = fileManager.fileExists(atPath: atPath, isDirectory: &isDirectory)

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

func createOrReplaceSymlink(from: String, to: String) throws {
    let fileManager = FileManager()

    var isDirectory: ObjCBool = ObjCBool(false)
    let exists = fileManager.fileExists(atPath: to, isDirectory: &isDirectory)
    if exists || isDirectory.boolValue {
        log.trace("Symlink exists, removing \(to)")
        try fileManager.removeItem(atPath: to)
    }

    try fileManager.createSymbolicLink(atPath: to, withDestinationPath: from)
}

func joinPath(paths: String...) -> String {
    return paths.filter({$0 != ""}).joined(separator: "/")
}

func joinPath(paths: [String]) -> String {
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

func pathWithoutFileName(atPath: String) -> String? {
    let url = NSURL(fileURLWithPath: atPath)
    return url.deletingLastPathComponent?.relativeString
}

func resizeImage(imageSource: CGImageSource, maxResolution: Int, compression: CGFloat) -> Data? {
    // get source properties so we retain metadata (EXIF) for the downsized image
    if var metaData = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
        let width = metaData[kCGImagePropertyPixelWidth as String] as? Int,
        let height = metaData[kCGImagePropertyPixelHeight as String] as? Int {

        let srcMaxResolution = max(width, height)

        // if max resolution is exceeded, then scale image to new resolution
        if srcMaxResolution >= maxResolution {
            let scaleOptions  = [ kCGImageSourceThumbnailMaxPixelSize as String: maxResolution,
                                  kCGImageSourceCreateThumbnailFromImageAlways as String: true] as [String: Any]

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

extension Date {
    var millisecondsSince1970: Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }

    init(milliseconds: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds / 1000))
    }
}

// When the modified date is encoded to json, the millisecond accuracy is lost.
// Therefore we remove it before so we can do a proper equal of the picture to
// seconds accuracy.
func fileModificationDate(url: URL) -> Date? {
    do {
        let attr = try FileManager.default.attributesOfItem(atPath: url.path)
        if let date = attr[FileAttributeKey.modificationDate] as? Date {
            let rounded = date.millisecondsSince1970 - (date.millisecondsSince1970 % 1000)
            let roundedDate = Date(milliseconds: rounded)
            return roundedDate
        }
        return nil
    } catch {
        return nil
    }
}

func prettyPrintAlbum(_ album: Album) {
    let indentCharacter = "  "
    func prettyPrintAlbumRecursive(_ album: Album, indent: Int) {
        let indentString = String(repeating: indentCharacter, count: indent)
        let indentChildString = String(repeating: indentCharacter, count: indent + 1)

        // TODO: Determine of this should be log or print
        print("\(indentString)Album: \(album.name): \(album.path)")
        for photo in album.photos {
            // TODO: Determine of this should be log or print
            print("\(indentChildString)Photo: \(photo.name): \(photo.url)")
        }
        for childAlbum in album.albums {
            prettyPrintAlbumRecursive(childAlbum, indent: indent + 1)
        }
    }
    prettyPrintAlbumRecursive(album, indent: 0)
}

func prettyPrintAdded(_ album: Album) {
    prettyPrintAlbumCompact(album, marker: "[+]".green)
}

func prettyPrintRemoved(_ album: Album) {
    prettyPrintAlbumCompact(album, marker: "[-]".red)
}

func prettyPrintAlbumCompact(_ album: Album, marker: String) {
    if !album.photos.isEmpty {
        print("Album: \(album.url)")
    }
    for photo in album.photos {
        print("\(marker): \(photo.url)")
    }

    for childAlbum in album.albums {
        prettyPrintAlbumCompact(childAlbum, marker: marker)
    }
}

func urlifyName(_ name: String) -> String {
    return name.replacingOccurrences(of: " ", with: "_")
}

extension Collection {
    /// Returns the element at the specified index iff it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
