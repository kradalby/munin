import Foundation
import SwiftExif
import VIPS

/// Read a photo from disk, extracting EXIF/IPTC metadata, orientation, GPS,
/// keywords/people, location data, and building the `scaledPhotos` list.
///
/// Returns `nil` only if VIPS could not open the image at all; all lesser
/// failures (missing EXIF block, missing GPS, etc.) are logged at trace
/// level and produce a partially-populated `Photo`.
// swiftlint:disable:next cyclomatic_complexity function_body_length
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

  // sourceHash is the incremental-rebuild signal: identical bytes →
  // equal Photo → no re-encode. A hash failure here is non-fatal (the
  // photo falls back to nil, which compares unequal to any hashed
  // counterpart and forces a rebuild — the conservative choice).
  do {
    photo.sourceHash = try ContentHash.sha256(ofFileAt: atPath)
  } catch {
    ctx.log.warning("Could not hash source photo at \(atPath): \(error)")
  }

  do {
    let image = try VIPSImage(fromFilePath: fileURL.path)
    let width = image.size.width
    let height = image.size.height
    photo.width = width
    photo.height = height

    // Determine display orientation by combining the raw pixel dimensions
    // with the EXIF orientation hint. EXIF orientations 5–8 imply a 90°
    // or 270° rotation, which effectively swaps the width/height we see.
    if image.orientationSwap {
      photo.orientation = width > height ? .portrait : .landscape
    } else {
      photo.orientation = width < height ? .portrait : .landscape
    }

  } catch {
    ctx.log.error("Could not open image at \(fileURL.path): \(error)")
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
      if photo.width != nil {
        ctx.log.trace("Width already set, ignoring EXIF width")
      } else {
        photo.width = Int(width)
      }
    }

    if let height = exif["Pixel Y Dimension"] {
      if photo.height != nil {
        ctx.log.trace("Height already set, ignoring EXIF height")
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
    ctx.log.warning("Exif tag not found for photo, some metatags will be unavailable")
  }

  let maxResolution = max(photo.width ?? 0, photo.height ?? 0)

  photo.scaledPhotos = ctx.config.resolutions.filter { $0 < maxResolution }.map({
    ScaledPhoto(
      url: "\(joinPath(outPath, name))_\($0).\(fileExtension)",
      maxResolution: $0
    )
  })

  if let zero = exifDict["0"] {
    photo.cameraMake = zero["Manufacturer"]
    photo.cameraModel = zero["Model"]
    photo.copyright = zero["Artist"] ?? zero["Copyright"]

  } else {
    ctx.log.warning("'0' (zero) tag not found for photo, some metatags will be unavailable")
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
      if ctx.config.allPeople.contains(keyword) {
        photo.people.append(keywordPointer)
      } else {
        photo.keywords.append(keywordPointer)
      }
    }
  }

  if let gpsDict = exifDict["GPS"],
    let altitudeStr = gpsDict["Altitude"],
    let latitudeStr = gpsDict["Latitude"],
    let longitudeStr = gpsDict["Longitude"],
    let altitude = Double(altitudeStr),
    let latitude = LocationDegree.fromString(latitudeStr),
    let longitude = LocationDegree.fromString(longitudeStr),
    let longitudeRef = gpsDict["East or West Longitude"],
    let latitudeRef = gpsDict["North or South Latitude"]
  {
    let latDecimal = latitudeRef == "N" ? latitude.toDecimal() : -latitude.toDecimal()
    let lonDecimal = longitudeRef == "E" ? longitude.toDecimal() : -longitude.toDecimal()
    photo.gps = GPS(altitude: altitude, latitude: latDecimal, longitude: lonDecimal)
  } else {
    // Missing GPS data is a normal condition (indoor shots, anonymised EXIF),
    // not a warning.
    ctx.log.trace("GPS tag not found for photo")
  }

  photo.keywords = Array(Set(photo.keywords)).sorted()
  photo.people = Array(Set(photo.people)).sorted()

  return photo
}
