//
//  Photo.swift
//  g
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Dispatch
import Foundation
import Logging
import SwiftExif
import SwiftGD

struct Photo: Codable, Comparable, Hashable, Diffable {
  var name: String
  var url: String
  var originalImageURL: String
  var originalImagePath: String
  var scaledPhotos: [ScaledPhoto]
  var parents: [Parent]

  // Metadata
  var aperture: Double?
  var apertureFormatted: String?
  var cameraMake: String?
  var cameraModel: String?
  var copyright: String?
  var dateTime: Date?
  var exposureTime: Double?
  var exposureTimeFormatted: String?
  var fNumber: Double?
  var fNumberFormatted: String?
  var focalLength: Double?
  var focalLengthFormatted: String?
  var gps: GPS?
  var height: Int?
  var imageDescription: String?
  var isoSpeed: Set<Int>
  var lensModel: String?
  var location: LocationData?
  var meteringMode: Int?
  var meteringModeFormatted: String?
  var modifiedDate: Date
  var orientation: Orientation?
  var owner: String?
  var shutterSpeed: Double?
  var shutterSpeedFormatted: String?
  var width: Int?

  var keywords: [KeywordPointer]
  var people: [KeywordPointer]
  var next: String?
  var previous: String?

  init(
    name: String,
    url: String,
    originalImageURL: String,
    originalImagePath: String,
    scaledPhotos: [ScaledPhoto],
    modifiedDate: Date,
    parents: [Parent]
  ) {
    self.name = name
    self.url = url
    self.originalImageURL = originalImageURL
    self.originalImagePath = originalImagePath
    self.scaledPhotos = scaledPhotos
    self.parents = parents
    self.modifiedDate = modifiedDate
    isoSpeed = []
    keywords = []
    people = []
  }

  // Intended for sort testing.
  init(
    name: String,
    dateTime: Date? = nil
  ) {
    self.name = name
    self.url = ""
    self.originalImageURL = ""
    self.originalImagePath = ""
    self.scaledPhotos = []
    self.parents = []
    self.modifiedDate = Date()
    self.dateTime = dateTime
    isoSpeed = []
    keywords = []
    people = []
  }
}

struct ScaledPhoto: Codable, AutoEquatable, Comparable {
  var url: String
  var maxResolution: Int

  static func < (lhs: ScaledPhoto, rhs: ScaledPhoto) -> Bool {
    return lhs.maxResolution < rhs.maxResolution
  }
}

struct GPS: Codable, AutoEquatable {
  var altitude: Double
  var latitude: Double
  var longitude: Double
}

struct LocationData: Codable, AutoEquatable {
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
  static func < (lhs: Photo, rhs: Photo) -> Bool {
    // Sort by date (exif, taken date) if it is available
    if let lhsDateTime = lhs.dateTime, let rhsDateTime = rhs.dateTime {

      // If taken at _exactly_ the same time, use name
      if lhsDateTime == rhsDateTime {
        return lhs.name < rhs.name
      }

      return lhsDateTime < rhsDateTime
    }

    // If only one has a date, consider that the winner
    if let _ = lhs.dateTime {
      return true
    }

    if let _ = rhs.dateTime {
      return false
    }

    // Fallback to name
    return lhs.name < rhs.name
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(url)
  }
}

extension Photo {
  func write(ctx: Context, writeJson: Bool, writeImage: Bool) {
    log.trace("Photo: \(name) has \(writeImage)")
    // Only write images and symlink if the user wants to
    if writeImage {
      log.trace("Writing image \(name)")
      let fileURL = URL(fileURLWithPath: originalImagePath)
      if let image = Image(url: fileURL) {
        for scaledPhoto in scaledPhotos {
          if let resizedImage = image.resizedTo(width: scaledPhoto.maxResolution) {
            log.trace(
              "Writing image \(name) at \(scaledPhoto.maxResolution)px to \(scaledPhoto.url)")
            if !resizedImage.write(
              to: URL(fileURLWithPath: scaledPhoto.url),
              quality: Int(100 * ctx.config.jpegCompression))
            {
              log.error("Could not write image \(name) to \(scaledPhoto.url)")
            }
          }
        }
      }

      let relativeOriginialPath = Array(repeating: "..", count: depth()) + [originalImagePath]
      log.trace("Symlinking original image \(name) to \(originalImageURL)")
      do {
        try createOrReplaceSymlink(
          source: joinPath(relativeOriginialPath),
          destination: originalImageURL
        )
      } catch {
        log.error("Could not symlink image \(name) to \(originalImageURL) with error: \n\(error)")
      }
    }

    if writeJson {
      log.trace("Writing metadata for image \(name)")
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601

      if let encodedData = try? encoder.encode(self) {
        do {
          log.trace("Writing image metadata \(name) to \(url)")
          try encodedData.write(to: URL(fileURLWithPath: url))
        } catch {
          log.error("Could not write image \(name) to \(url) with error: \n\(error)")
        }
      }
    }
  }

  func destroy(ctx: Context) {
    let fileManager = FileManager()
    log.trace("Removing image \(name)")
    let jsonURL = URL(fileURLWithPath: url)
    let symlinkedImageURL = URL(fileURLWithPath: originalImageURL)
    do {
      try fileManager.removeItem(at: jsonURL)
    } catch {
      log.error("Could not remove image json \(name) at path \(url)")
    }

    do {
      try fileManager.removeItem(at: symlinkedImageURL)
    } catch {
      log.error("Could not remove image json \(name) at path \(originalImageURL)")
    }

    for scaledPhoto in scaledPhotos {
      let fileURL = URL(fileURLWithPath: scaledPhoto.url)
      do {
        try fileManager.removeItem(at: fileURL)
      } catch {
        log.error("Could not remove image \(name) at path \(scaledPhoto.url)")
      }
    }
  }

  func expectedFiles() -> [URL] {
    let jsonURL = URL(fileURLWithPath: url)
    let symlinkedImageURL = URL(fileURLWithPath: originalImageURL)
    let expectedFiles =
      [jsonURL, symlinkedImageURL] + scaledPhotos.map { URL(fileURLWithPath: $0.url) }

    return expectedFiles
  }

  func depth() -> Int {
    let urlSeparator: Character = "/"
    var counter = 0
    for char in url where char == urlSeparator {
      counter += 1
    }
    return counter
  }

  func include() -> Bool {
    for keyword in keywords where keyword.name == "NO_HUGIN" {
      return false
    }
    return true
  }
}

extension Photo: CustomStringConvertible {
  var description: String {
    return "Photo: \(name) modDate: \(modifiedDate))"
  }
}

func readPhotoFromPath(
  atPath: String,
  outPath: String,
  name: String,
  fileExtension: String,
  parents: [Parent],
  ctx: Context
) -> Photo? {
  let dateFormatter = DateFormatter()
  dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"

  let fileURL = URL(fileURLWithPath: atPath)

  let exifImage = SwiftExif.Image(imagePath: fileURL)
  let exifDict = exifImage.Exif()
  let exifRawDict = exifImage.ExifRaw()
  let iptcDict = exifImage.Iptc()

  var photo = Photo(
    name: name,
    url: "\(joinPath(outPath, name)).json",
    originalImageURL: "\(joinPath(outPath, name))_original.\(fileExtension)",
    originalImagePath: atPath,
    scaledPhotos: [],
    // If no modifiation date is available, use now.
    modifiedDate: fileModificationDate(url: fileURL) ?? Date(),
    parents: parents
  )

  // Use GD to check for the width/height
  if let image = Image(url: fileURL) {
    photo.width = image.size.width
    photo.height = image.size.height
  }

  if let exif = exifRawDict["EXIF"] {
    if let aperture = exif["Aperture"] {
      photo.aperture = Double(aperture)
    }

    if let fNumber = exif["F-Number"] {
      photo.fNumber = Double(fNumber)
    }
    if let meteringMode = exif["Metering Mode"] {
      photo.meteringMode = Int(meteringMode)
    }
    if let shutterSpeed = exif["Shutter Speed"] {
      photo.shutterSpeed = Double(shutterSpeed)
    }
    if let focalLength = exif["Focal Length"] {
      photo.focalLength = Double(focalLength)
    }
    if let exposureTime = exif["Exposure Time"] {
      photo.exposureTime = Double(exposureTime)
    }
  }

  if let exif = exifDict["EXIF"] {
    if let width = exif["Pixel X Dimension"] {
      if let _ = photo.width {
        log.trace("Width already set, ignoring EXIF width")
      } else {
        photo.width = Int(width)
      }
    }

    if let height = exif["Pixel Y Dimension"] {
      if let _ = photo.height {
        log.trace("Height already set, ignoring EXIF height")
      } else {
        photo.height = Int(height)
      }
    }

    if let aperture = exif["Aperture"] {
      photo.apertureFormatted = aperture
    }

    if let fNumber = exif["F-Number"] {
      photo.fNumberFormatted = fNumber
    }
    if let meteringMode = exif["Metering Mode"] {
      photo.meteringModeFormatted = meteringMode
    }
    if let shutterSpeed = exif["Shutter Speed"] {
      photo.shutterSpeedFormatted = shutterSpeed
    }
    if let focalLength = exif["Focal Length"] {
      photo.focalLengthFormatted = focalLength
    }
    if let exposureTime = exif["Exposure Time"] {
      photo.exposureTimeFormatted = exposureTime
    }

    if let isoSpeedStr = exif["ISO Speed Ratings"] {
      if let isoSpeed = Int(isoSpeedStr) {
        photo.isoSpeed = Set([isoSpeed])
      }
    }
    if let dateTime = exif["Date and Time (Original)"] {
      photo.dateTime = dateFormatter.date(from: dateTime)
    }

    photo.lensModel = exif["Lens Model"]
    photo.owner = exif["Camera Owner Name"]

  } else {
    log.warning("Exif tag not found for photo, some metatags will be unavailable")
  }

  if let width = photo.width, let height = photo.height {
    if width > height {
      photo.orientation = Orientation.landscape
    } else {
      photo.orientation = Orientation.portrait
    }
  }

  let maxResolution = max(photo.width ?? 0, photo.height ?? 0)

  photo.scaledPhotos = ctx.config.resolutions.filter { $0 < maxResolution }.map({
    ScaledPhoto(
      url: "\(joinPath(outPath, name))_\($0).\(fileExtension)",
      maxResolution: $0
    )
  }
  )

  if let zero = exifDict["0"] {
    photo.cameraMake = zero["Manufacturer"]
    photo.cameraModel = zero["Model"]
    photo.copyright = zero["Artist"] ?? zero["Copyright"]

  } else {
    log.warning("'0' (zero) tag not found for photo, some metatags will be unavailable")
  }

  // Add location data if available
  if let city = iptcDict["City"] as? String,
    let state = iptcDict["Province/State"] as? String,
    let locationCode = iptcDict["Country Code"] as? String,
    let locationName = iptcDict["Country Name"] as? String
  {
    photo.location = LocationData(
      city: city,
      state: state,
      locationCode: locationCode,
      locationName: locationName)

    // Add location names as keywords
    let stateKeyword = KeywordPointer(
      name: state,
      url: "\(ctx.config.outputPath)/keywords/\(urlifyName(state)).json"
    )
    let locationCodeKeyword = KeywordPointer(
      name: locationCode,
      url: "\(ctx.config.outputPath)/keywords/\(urlifyName(locationCode)).json"
    )
    let locationNameKeyword = KeywordPointer(
      name: locationName,
      url: "\(ctx.config.outputPath)/keywords/\(urlifyName(locationName)).json"
    )

    photo.keywords.append(stateKeyword)
    photo.keywords.append(locationCodeKeyword)
    photo.keywords.append(locationNameKeyword)
  }

  if let keywords = iptcDict["Keywords"] as? [String] {
    for keyword in keywords {
      let keywordPointer = KeywordPointer(
        name: keyword,
        url: "\(ctx.config.outputPath)/keywords/\(urlifyName(keyword)).json"
      )
      if ctx.config.allPeople().contains(keyword) {
        photo.people.append(keywordPointer)
      } else {
        photo.keywords.append(keywordPointer)
      }
    }
  }

  if let gpsDict = exifDict["GPS"] {
    if let altitudeStr = gpsDict["Altitude"],
      let latitudeStr = gpsDict["Latitude"],
      let longitudeStr = gpsDict["Longitude"]
    {
      if let altitude = Double(altitudeStr),
        let latitude = LocationDegree.fromString(latitudeStr),
        let longitude = LocationDegree.fromString(longitudeStr),
        let longitudeRef = gpsDict["East or West Longitude"],
        let latitudeRef = gpsDict["North or South Latitude"]
      {
        photo.gps = GPS(
          altitude: altitude,
          latitude: latitudeRef == "N"
            ? latitude.toDecimal()
            : latitude.toDecimal() * -1,
          longitude: longitudeRef == "E" ? longitude.toDecimal() : longitude.toDecimal() * -1
        )
      }

    }

  } else {
    log.warning("GPS tag not found for photo, some metatags will be unavailable")
  }

  photo.keywords = Array(Set(photo.keywords)).sorted()
  photo.people = Array(Set(photo.people)).sorted()

  return photo
}
