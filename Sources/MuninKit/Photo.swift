//
//  Photo.swift
//  g
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Foundation
import ImageIO

struct Photo: Codable, Comparable, Hashable {
    var name: String
    var url: String
    var originalImageURL: String
    var originalImagePath: String
    var scaledPhotos: [ScaledPhoto]
    var parents: [Parent]

    // Metadata
    var aperture: Double?
    var dateTime: Date?
    var fNumber: Double?
    var focalLength: Double?
    var exposureTime: Double?
    var isoSpeed: Set<Int>
    var width: Int?
    var height: Int?
    var meteringMode: Int?
    var shutterSpeed: Double?
    var lensModel: String?
    var owner: String?
    var gps: GPS?
    var location: LocationData?
    var imageDescription: String?
    var cameraMake: String?
    var cameraModel: String?
    var copyright: String?
    var orientation: Orientation?
    var modifiedDate: Date
    var keywords: Set<KeywordPointer>
    var people: Set<KeywordPointer>
    var next: String?
    var previous: String?

    init(name: String, url: String, originalImageURL: String, originalImagePath: String, scaledPhotos: [ScaledPhoto], modifiedDate: Date, parents: [Parent]) {
        self.name = name
        self.url = url
        self.originalImageURL = originalImageURL
        self.originalImagePath = originalImagePath
        self.scaledPhotos = scaledPhotos
        self.parents = parents
        self.modifiedDate = modifiedDate
        self.isoSpeed = []
        self.keywords = []
        self.people = []
    }
}

struct ScaledPhoto: Codable, AutoEquatable {
//    static func ==(lhs: ScaledPhoto, rhs: ScaledPhoto) -> Bool {
//        guard lhs.url == rhs.url else { return false }
//        guard lhs.maxResolution == rhs.maxResolution else { return false }
//        return true
//    }

    var url: String
    var maxResolution: Int
}

struct GPS: Codable, AutoEquatable {
//    static func ==(lhs: GPS, rhs: GPS) -> Bool {
//        guard lhs.altitude == rhs.altitude else { return false }
//        guard lhs.latitude == rhs.latitude else { return false }
//        guard lhs.longitude == rhs.longitude else { return false }
//        return true
//    }

    var altitude: Double
    var latitude: Double
    var longitude: Double
}

struct LocationData: Codable, AutoEquatable {
//    static func ==(lhs: LocationData, rhs: LocationData) -> Bool {
//        guard lhs.city == rhs.city else { return false }
//        guard lhs.state == rhs.state else { return false }
//        guard lhs.locationCode == rhs.locationCode else { return false }
//        guard lhs.locationName == rhs.locationName else { return false }
//
//        return true
//    }

    var city: String
    var state: String
    var locationCode: String
    var locationName: String
}

enum Orientation: String, Codable {
    case landscape
    case portrait
}

extension Photo: AutoEquatable {
//    static func ==(lhs: Photo, rhs: Photo) -> Bool {
//        guard lhs.name == rhs.name else { return false }
//        guard lhs.url == rhs.url else { return false }
//        guard lhs.originalImageURL == rhs.originalImageURL else { return false }
//        guard lhs.originalImagePath == rhs.originalImagePath else { return false }
//        guard lhs.scaledPhotos == rhs.scaledPhotos else { return false }
//        guard lhs.parents == rhs.parents else { return false }
//
//        // Metadata
//        guard lhs.aperture == rhs.aperture else { return false }
//        guard lhs.dateTime == rhs.dateTime else { return false }
//        guard lhs.fNumber == rhs.fNumber else { return false }
//        guard lhs.focalLength == rhs.focalLength else { return false }
//        guard lhs.isoSpeed == rhs.isoSpeed else { return false }
//        guard lhs.width == rhs.width else { return false }
//        guard lhs.height == rhs.height else { return false }
//        guard lhs.meteringMode == rhs.meteringMode else { return false }
//        guard lhs.shutterSpeed == rhs.shutterSpeed else { return false }
//        guard lhs.lensModel == rhs.lensModel else { return false }
//        guard lhs.owner == rhs.owner else { return false }
//        guard lhs.gps == rhs.gps else { return false }
//        guard lhs.location == rhs.location else { return false }
//        guard lhs.imageDescription == rhs.imageDescription else { return false }
//        guard lhs.cameraMake == rhs.cameraMake else { return false }
//        guard lhs.cameraModel == rhs.cameraModel else { return false }
//        guard lhs.copyright == rhs.copyright else { return false }
//
////        if lhs.modifiedDate != rhs.modifiedDate {
////            log.debug("image: \(lhs.name)")
////            log.debug("\(lhs.modifiedDate) \(rhs.modifiedDate) \(lhs.modifiedDate == rhs.modifiedDate)")
////            log.debug("\(lhs.modifiedDate.timeIntervalSince(rhs.modifiedDate))")
////
////        }
//
//        guard lhs.modifiedDate == rhs.modifiedDate else { return false }
//        guard lhs.keywords == rhs.keywords else { return false }
//        guard lhs.people == rhs.people else { return false }
//        return true
//    }

    static func <(lhs: Photo, rhs: Photo) -> Bool {
        return lhs.name < rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

}

extension Photo {
    func write(config: GalleryConfiguration, writeJson: Bool, writeImage: Bool) {

        log.info("Photo: \(self.name) has \(writeImage)")
        // Only write images and symlink if the user wants to
        if writeImage {
            log.info("Writing image \(self.name)")
            let fileURL = NSURL.fileURL(withPath: self.originalImagePath)
            if let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) {
                for scaledPhoto in self.scaledPhotos {
                    if let resizedImageData = resizeImage(imageSource: imageSource, maxResolution: scaledPhoto.maxResolution, compression: CGFloat(config.jpegCompression)) {
                        log.trace("Writing image \(self.name) at \(scaledPhoto.maxResolution)px to \(scaledPhoto.url)")
                        do {
                            try resizedImageData.write(to: URL(fileURLWithPath: scaledPhoto.url))
                        } catch {
                            log.error("Could not write image \(self.name) to \(scaledPhoto.url) with error: \n\(error)")
                        }
                    }
                }
            }

            let relativeOriginialPath = Array(repeating: "..", count: self.depth()) + [self.originalImagePath]
            log.info("Symlinking original image \(self.name) to \(self.originalImageURL)")
            do {
                try createOrReplaceSymlink(from: joinPath(paths: relativeOriginialPath), to: self.originalImageURL)
            } catch {
                log.error("Could not symlink image \(self.name) to \(self.originalImageURL) with error: \n\(error)")
            }

        }

        if writeJson {
            log.info("Writing metadata for image \(self.name)")
            let encoder = JSONEncoder()
            if #available(OSX 10.12, *) {
                encoder.dateEncodingStrategy = .iso8601
            }

            if let encodedData = try? encoder.encode(self) {
                do {
                    log.trace("Writing image metadata \(self.name) to \(self.url)")
                    try encodedData.write(to: URL(fileURLWithPath: self.url))
                } catch {
                    log.error("Could not write image \(self.name) to \(self.url) with error: \n\(error)")
                }
            }
        }
    }

    func destroy(config: GalleryConfiguration) {
        let fm = FileManager()
        log.trace("Removing image \(self.name)")
        let jsonURL = NSURL.fileURL(withPath: self.url)
        let symlinkedImageURL = NSURL.fileURL(withPath: self.originalImageURL)
        do {
            try fm.removeItem(at: jsonURL)
        } catch {
            log.error("Could not remove image json \(self.name) at path \(self.url)")
        }

        do {
            try fm.removeItem(at: symlinkedImageURL)
        } catch {
            log.error("Could not remove image json \(self.name) at path \(self.originalImageURL)")
        }

        for scaledPhoto in self.scaledPhotos {
            let fileURL = NSURL.fileURL(withPath: scaledPhoto.url)
            do {
                try fm.removeItem(at: fileURL)
            } catch {
                log.error("Could not remove image \(self.name) at path \(scaledPhoto.url)")
            }
        }

    }

    func depth() -> Int {
        let char: Character = "/"
        var counter = 0
        for c in self.url {
            if c == char {
                counter += 1
            }
        }
        return counter
    }

    func include() -> Bool {
        for keyword in self.keywords {
            if keyword.name == "NO_HUGIN" {
                return false
            }
        }
        return true
    }
}

func readPhotoFromPath(
    atPath: String,
    outPath: String,
    name: String,
    fileExtension: String,
    parents: [Parent],
    config: GalleryConfiguration
    ) -> Photo? {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"

    let fileURL = NSURL.fileURL(withPath: atPath)
    if let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) {

        // Get md5 of original
        //        log.trace("Calculating md5 hash for original image \(name)")
        //        if let imageFile = try? Data(contentsOf: URL(fileURLWithPath: atPath)) {
        //            let md5 = MD5()
        //            let hash = md5.calculate(for: imageFile.bytes)
        //            print(hash.toHexString())
        //        }

        let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
        if let dict = imageProperties as? [String: Any] {
            var photo = Photo(
                name: name,
                url: "\(joinPath(paths: outPath, name)).json",
                originalImageURL: "\(joinPath(paths: outPath, name))_original.\(fileExtension)",
                originalImagePath: atPath,
                scaledPhotos: config.resolutions.map({ScaledPhoto(
                        url: "\(joinPath(paths: outPath, name))_\($0).\(fileExtension)",
                        maxResolution: $0)
                    }
                ),
                // If no modifiation date is available, use now.
                modifiedDate: fileModificationDate(url: fileURL) ?? Date(),
                parents: parents
            )

            photo.width = dict["PixelWidth"] as? Int
            photo.height = dict["PixelHeight"] as? Int

            if let width = photo.width, let height = photo.height {
                if width > height {
                    photo.orientation = Orientation.landscape
                } else {
                    photo.orientation = Orientation.portrait
                }
            }

            if let exif = dict["{Exif}"] as? [String: Any] {
                photo.aperture = exif["ApertureValue"] as? Double
                photo.fNumber = exif["FNumber"] as? Double
                photo.meteringMode = exif["MeteringMode"] as? Int
                photo.shutterSpeed = exif["ShutterSpeedValue"] as? Double
                photo.focalLength = exif["FocalLength"] as? Double
                photo.exposureTime = exif["ExposureTime"] as? Double
                if let dateTime = exif["DateTimeOriginal"] as? String {
                    photo.dateTime = dateFormatter.date(from: dateTime)
                }

                if let isoSpeed = exif["ISOSpeedRatings"] as? [Int] {
                    photo.isoSpeed = Set(isoSpeed)
                }
            } else {
                log.warning("Exif tag not found for photo, some metatags will be unavailable")
            }

            if let tiff = dict["{TIFF}"] as? [String: Any] {
                photo.imageDescription = tiff["ImageDescription"] as? String
                photo.cameraMake = tiff["Make"] as? String
                photo.cameraModel = tiff["Model"] as? String

            } else {
                log.warning("TIFF tag not found for photo, some metatags will be unavailable")
            }

            if let iptc = dict["{IPTC}"] as? [String: Any] {

                // Add location data if available
                if let city = iptc["City"] as? String,
                    let state = iptc["Province/State"] as? String,
                    let locationCode = iptc["Country/PrimaryLocationCode"] as? String,
                    let locationName = iptc["Country/PrimaryLocationName"] as? String {

                    photo.location = LocationData(city: city,
                                              state: state,
                                              locationCode: locationCode,
                                              locationName: locationName
                    )

                    // Add location names as keywords
                    let stateKeyword = KeywordPointer(name: state, url: "\(config.outputPath)/keywords/\(urlifyName(state)).json")
                    let locationCodeKeyword = KeywordPointer(name: locationCode, url: "\(config.outputPath)/keywords/\(urlifyName(locationCode)).json")
                    let locationNameKeyword = KeywordPointer(name: locationName, url: "\(config.outputPath)/keywords/\(urlifyName(locationName)).json")

                    photo.keywords.insert(stateKeyword)
                    photo.keywords.insert(locationCodeKeyword)
                    photo.keywords.insert(locationNameKeyword)
                }

                photo.copyright = iptc["CopyrightNotice"] as? String

                if let keywords = iptc["Keywords"] as? [String] {
                    for keyword in keywords {
                        let keywordPointer = KeywordPointer(name: keyword, url: "\(config.outputPath)/keywords/\(urlifyName(keyword)).json")
                        if config.people.contains(keyword) {
                            photo.people.insert(keywordPointer)
                        } else {
                            photo.keywords.insert(keywordPointer)
                        }
                    }
                }
            } else {
                log.warning("IPTC tag not found for photo, some metatags will be unavailable")
            }

            if let exifAux = dict["{ExifAux}"] as? [String: Any] {
                photo.lensModel = exifAux["LensModel"] as? String
                photo.owner = exifAux["OwnerName"] as? String

            } else {
                log.warning("ExifAux tag not found for photo, some metatags will be unavailable")
            }

            if let gpsDict = dict["{GPS}"] as? [String: Any] {
                if let altitude = gpsDict["Altitude"] as? Double,
                    let latitude = gpsDict["Latitude"] as? Double,
                    let longitude = gpsDict["Longitude"] as? Double {
                photo.gps = GPS(
                    altitude: altitude,
                    latitude: latitude,
                    longitude: longitude
                    )
                }
            } else {
                log.warning("GPS tag not found for photo, some metatags will be unavailable")
            }

            return photo
        }
    }
    return nil
}
