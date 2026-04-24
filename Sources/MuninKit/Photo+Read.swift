import Foundation
import SwiftExif
import VIPS

/// Read a photo from disk, extracting EXIF/IPTC metadata, orientation, GPS,
/// keywords/people, location data, and building the `scaledPhotos` list.
///
/// Returns `nil` only if VIPS could not open the image at all; all lesser
/// failures (missing EXIF block, missing GPS, etc.) are logged at trace
/// level and produce a partially-populated `Photo`.
///
/// When `prior` is supplied (the previously-written `Photo` for this
/// output URL), the function takes one of three fast paths before falling
/// through to the full EXIF/VIPS/hash read:
///
/// 1. **Cache hit**: `prior.fileSize` and `prior.modifiedDate` match the
///    file on disk AND `prior.sourceHash` is non-nil. Nothing has been
///    touched; return `prior` verbatim. No hash, no EXIF, no VIPS.
/// 2. **Upgrade path**: `(fileSize, modifiedDate)` match but
///    `prior.sourceHash` is nil (pre-sourceHash output). Hash the bytes,
///    attach the hash to `prior`, return it. Subsequent runs hit path 1.
/// 3. **Mtime drift**: `(fileSize, modifiedDate)` differ but hashing the
///    current bytes yields `prior.sourceHash`. The file was touched but
///    bytes are unchanged; refresh the cache keys on `prior` and return
///    it. The next run hits path 1.
///
/// Any other case — prior absent, prior hashless with a drift, or hash
/// mismatch — falls through to the full read, which computes a fresh
/// sourceHash and produces a new Photo.
// swiftlint:disable:next cyclomatic_complexity function_body_length
func readPhotoFromPath(
  atPath: String,
  outPath: String,
  name: String,
  fileExtension: String,
  parents: [Parent],
  ctx: Context,
  prior: Photo? = nil
) -> Photo? {
  let fileURL = URL(fileURLWithPath: atPath)
  let currentMtime = fileModificationDate(url: fileURL) ?? Date()
  let currentSize = fileSizeInBytes(url: fileURL)

  // One-shot hash: compute on demand at most once per call. Used by
  // fast-path 2 (upgrade), fast-path 3 (mtime drift), and the slow-path
  // write to `photo.sourceHash` below.
  var computedHash: String?? = nil
  func currentHash() -> String? {
    if let cached = computedHash { return cached }
    let value = try? ContentHash.sha256(ofFileAt: atPath)
    computedHash = value
    return value
  }

  // Fast path 1 + 2: on-disk (size, mtime) still match the recorded
  // cache keys on prior.
  if let prior,
    let priorSize = prior.fileSize,
    let currentSize,
    priorSize == currentSize,
    prior.modifiedDate == currentMtime
  {
    var reused = prior
    if reused.sourceHash == nil {
      // Upgrade path: store a hash this time so future runs hit the
      // pure no-op case.
      reused.sourceHash = currentHash()
      reused.fileSize = currentSize
    }
    applyConfigDerivedFields(
      to: &reused, outPath: outPath, name: name, fileExtension: fileExtension, ctx: ctx)
    return reused
  }

  // Fast path 3: mtime or size drifted. Hash the current bytes once and
  // compare against the recorded hash. Matching bytes mean the file was
  // touched but content is unchanged — reuse prior and refresh the
  // cache keys so subsequent runs hit path 1.
  if let prior,
    let priorHash = prior.sourceHash,
    let newHash = currentHash(),
    priorHash == newHash
  {
    var reused = prior
    reused.modifiedDate = currentMtime
    reused.fileSize = currentSize
    applyConfigDerivedFields(
      to: &reused, outPath: outPath, name: name, fileExtension: fileExtension, ctx: ctx)
    return reused
  }

  // Slow path: genuine change (or no prior). Read EXIF, probe with
  // VIPS, compute a fresh hash.
  let dateFormatter = DateFormatter()
  dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"

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
    modifiedDate: currentMtime,
    parents: parents
  )
  photo.fileSize = currentSize

  // sourceHash is the incremental-rebuild signal: identical bytes →
  // equal Photo → no re-encode. Reuse `currentHash()`'s cache so fast
  // path 3 above (which hashed to compare against the prior) doesn't
  // cause a redundant second read.
  photo.sourceHash = currentHash()
  if photo.sourceHash == nil {
    ctx.log.warning("Could not hash source photo at \(atPath)")
  }

  do {
    let image = try VIPSImage(fromFilePath: fileURL.path)
    VIPSBootstrap.didRunPipeline()
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

  applyConfigDerivedFields(
    to: &photo, outPath: outPath, name: name, fileExtension: fileExtension, ctx: ctx)

  return photo
}

/// Re-derive the parts of a `Photo` that depend on configuration rather
/// than source bytes. Called from every read path (fast and slow) so the
/// same logic covers cache-hit reuse and a fresh VIPS read.
///
/// Fields touched:
/// - `scaledPhotos`: recomputed from the current `ctx.config.resolutions`
///   using the photo's cached `width`/`height` for the max-resolution
///   filter.
/// - `keywords` / `people`: the union of both lists is re-split against
///   `ctx.config.allPeople`, so adding or removing an entry from
///   `peopleFiles` moves the pointer to the other bucket on the next
///   build.
/// - `encodingFingerprint`: a stable readable string over the config
///   values that determine encoded JPEG bytes. A mismatch between the
///   stored fingerprint on disk and the one computed here propagates
///   through `Photo.==` and re-encodes the scaled outputs.
private func applyConfigDerivedFields(
  to photo: inout Photo,
  outPath: String,
  name: String,
  fileExtension: String,
  ctx: Context
) {
  let maxResolution = max(photo.width ?? 0, photo.height ?? 0)
  photo.scaledPhotos = ctx.config.resolutions.filter { $0 < maxResolution }.map {
    ScaledPhoto(
      url: "\(joinPath(outPath, name))_\($0).\(fileExtension)",
      maxResolution: $0
    )
  }

  var newKeywords: [KeywordPointer] = []
  var newPeople: [KeywordPointer] = []
  for pointer in photo.keywords + photo.people {
    if ctx.config.allPeople.contains(pointer.name) {
      newPeople.append(pointer)
    } else {
      newKeywords.append(pointer)
    }
  }
  photo.keywords = Array(Set(newKeywords)).sorted()
  photo.people = Array(Set(newPeople)).sorted()

  photo.encodingFingerprint = encodingFingerprint(for: ctx.config)
}

/// Human-readable fingerprint over the config values that determine the
/// encoded bytes of the scaled JPEGs. `fileExtensions` is deliberately
/// excluded: it filters which files count as photos on input, not how
/// the encoder writes them on output.
func encodingFingerprint(for config: GalleryConfiguration) -> String {
  let quality = Int(config.jpegCompression * 100)
  let resolutions = config.resolutions.sorted().map(String.init).joined(separator: "_")
  return "q\(quality)_r\(resolutions)"
}
