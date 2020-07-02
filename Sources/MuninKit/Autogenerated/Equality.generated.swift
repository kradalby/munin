// Generated using Sourcery 0.18.0 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// MARK: Album Equatable

extension Album: Equatable {
  static func == (lhs: Album, rhs: Album) -> Bool {
    guard lhs.name == rhs.name else { return false }
    guard lhs.url == rhs.url else { return false }
    guard lhs.path == rhs.path else { return false }
    guard lhs.photos == rhs.photos else { return false }
    guard lhs.albums == rhs.albums else { return false }
    guard lhs.keywords == rhs.keywords else { return false }
    guard lhs.people == rhs.people else { return false }
    guard lhs.parents == rhs.parents else { return false }
    return true
  }
}

// MARK: GPS Equatable

extension GPS: Equatable {
  static func == (lhs: GPS, rhs: GPS) -> Bool {
    guard lhs.altitude == rhs.altitude else { return false }
    guard lhs.latitude == rhs.latitude else { return false }
    guard lhs.longitude == rhs.longitude else { return false }
    return true
  }
}

// MARK: Keyword Equatable

extension Keyword: Equatable {
  static func == (lhs: Keyword, rhs: Keyword) -> Bool {
    guard lhs.name == rhs.name else { return false }
    guard lhs.url == rhs.url else { return false }
    guard lhs.photos == rhs.photos else { return false }
    return true
  }
}

// MARK: LocationData Equatable

extension LocationData: Equatable {
  static func == (lhs: LocationData, rhs: LocationData) -> Bool {
    guard lhs.city == rhs.city else { return false }
    guard lhs.state == rhs.state else { return false }
    guard lhs.locationCode == rhs.locationCode else { return false }
    guard lhs.locationName == rhs.locationName else { return false }
    return true
  }
}

// MARK: Parent Equatable

extension Parent: Equatable {
  static func == (lhs: Parent, rhs: Parent) -> Bool {
    guard lhs.name == rhs.name else { return false }
    guard lhs.url == rhs.url else { return false }
    return true
  }
}

// MARK: Photo Equatable

extension Photo: Equatable {
  static func == (lhs: Photo, rhs: Photo) -> Bool {
    guard lhs.name == rhs.name else { return false }
    guard lhs.url == rhs.url else { return false }
    guard lhs.originalImageURL == rhs.originalImageURL else { return false }
    guard lhs.originalImagePath == rhs.originalImagePath else { return false }
    guard lhs.scaledPhotos == rhs.scaledPhotos else { return false }
    guard lhs.parents == rhs.parents else { return false }
    guard lhs.aperture == rhs.aperture else { return false }
    guard lhs.dateTime == rhs.dateTime else { return false }
    guard lhs.fNumber == rhs.fNumber else { return false }
    guard lhs.focalLength == rhs.focalLength else { return false }
    guard lhs.exposureTime == rhs.exposureTime else { return false }
    guard lhs.isoSpeed == rhs.isoSpeed else { return false }
    guard lhs.width == rhs.width else { return false }
    guard lhs.height == rhs.height else { return false }
    guard lhs.meteringMode == rhs.meteringMode else { return false }
    guard lhs.shutterSpeed == rhs.shutterSpeed else { return false }
    guard lhs.lensModel == rhs.lensModel else { return false }
    guard lhs.owner == rhs.owner else { return false }
    guard lhs.gps == rhs.gps else { return false }
    guard lhs.location == rhs.location else { return false }
    guard lhs.imageDescription == rhs.imageDescription else { return false }
    guard lhs.cameraMake == rhs.cameraMake else { return false }
    guard lhs.cameraModel == rhs.cameraModel else { return false }
    guard lhs.copyright == rhs.copyright else { return false }
    guard lhs.orientation == rhs.orientation else { return false }
    guard lhs.modifiedDate == rhs.modifiedDate else { return false }
    guard lhs.keywords == rhs.keywords else { return false }
    guard lhs.people == rhs.people else { return false }
    guard lhs.next == rhs.next else { return false }
    guard lhs.previous == rhs.previous else { return false }
    return true
  }
}

// MARK: ScaledPhoto Equatable

extension ScaledPhoto: Equatable {
  static func == (lhs: ScaledPhoto, rhs: ScaledPhoto) -> Bool {
    guard lhs.url == rhs.url else { return false }
    guard lhs.maxResolution == rhs.maxResolution else { return false }
    return true
  }
}
