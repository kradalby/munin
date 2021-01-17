// Generated using Sourcery 1.0.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT



// MARK: Album Equatable

extension Album: Equatable {
    static func == (lhs: Album, rhs: Album) -> Bool {
        guard lhs.name == rhs.name else { 
            print("name")
            print("\(lhs.name) != \(rhs.name)")
            return false 
        }
        guard lhs.url == rhs.url else { 
            print("url")
            print("\(lhs.url) != \(rhs.url)")
            return false 
        }
        guard lhs.path == rhs.path else { 
            print("path")
            print("\(lhs.path) != \(rhs.path)")
            return false 
        }
        guard lhs.photos == rhs.photos else { 
            print("photos")
            print("\(lhs.photos) != \(rhs.photos)")
            return false 
        }
        guard lhs.albums == rhs.albums else { 
            print("albums")
            print("\(lhs.albums) != \(rhs.albums)")
            return false 
        }
        guard lhs.keywords == rhs.keywords else { 
            print("keywords")
            print("\(lhs.keywords) != \(rhs.keywords)")
            return false 
        }
        guard lhs.people == rhs.people else { 
            print("people")
            print("\(lhs.people) != \(rhs.people)")
            return false 
        }
        guard lhs.parents == rhs.parents else { 
            print("parents")
            print("\(lhs.parents) != \(rhs.parents)")
            return false 
        }
        return true
    }
}

// MARK: GPS Equatable

extension GPS: Equatable {
    static func == (lhs: GPS, rhs: GPS) -> Bool {
        guard lhs.altitude == rhs.altitude else { 
            print("altitude")
            print("\(lhs.altitude) != \(rhs.altitude)")
            return false 
        }
        guard lhs.latitude == rhs.latitude else { 
            print("latitude")
            print("\(lhs.latitude) != \(rhs.latitude)")
            return false 
        }
        guard lhs.longitude == rhs.longitude else { 
            print("longitude")
            print("\(lhs.longitude) != \(rhs.longitude)")
            return false 
        }
        return true
    }
}

// MARK: Keyword Equatable

extension Keyword: Equatable {
    static func == (lhs: Keyword, rhs: Keyword) -> Bool {
        guard lhs.name == rhs.name else { 
            print("name")
            print("\(lhs.name) != \(rhs.name)")
            return false 
        }
        guard lhs.url == rhs.url else { 
            print("url")
            print("\(lhs.url) != \(rhs.url)")
            return false 
        }
        guard lhs.photos == rhs.photos else { 
            print("photos")
            print("\(lhs.photos) != \(rhs.photos)")
            return false 
        }
        return true
    }
}

// MARK: LocationData Equatable

extension LocationData: Equatable {
    static func == (lhs: LocationData, rhs: LocationData) -> Bool {
        guard lhs.city == rhs.city else { 
            print("city")
            print("\(lhs.city) != \(rhs.city)")
            return false 
        }
        guard lhs.state == rhs.state else { 
            print("state")
            print("\(lhs.state) != \(rhs.state)")
            return false 
        }
        guard lhs.locationCode == rhs.locationCode else { 
            print("locationCode")
            print("\(lhs.locationCode) != \(rhs.locationCode)")
            return false 
        }
        guard lhs.locationName == rhs.locationName else { 
            print("locationName")
            print("\(lhs.locationName) != \(rhs.locationName)")
            return false 
        }
        return true
    }
}

// MARK: LocationDegree Equatable

extension LocationDegree: Equatable {
    static func == (lhs: LocationDegree, rhs: LocationDegree) -> Bool {
        guard lhs.degrees == rhs.degrees else { 
            print("degrees")
            print("\(lhs.degrees) != \(rhs.degrees)")
            return false 
        }
        guard lhs.minutes == rhs.minutes else { 
            print("minutes")
            print("\(lhs.minutes) != \(rhs.minutes)")
            return false 
        }
        guard lhs.seconds == rhs.seconds else { 
            print("seconds")
            print("\(lhs.seconds) != \(rhs.seconds)")
            return false 
        }
        return true
    }
}

// MARK: Parent Equatable

extension Parent: Equatable {
    static func == (lhs: Parent, rhs: Parent) -> Bool {
        guard lhs.name == rhs.name else { 
            print("name")
            print("\(lhs.name) != \(rhs.name)")
            return false 
        }
        guard lhs.url == rhs.url else { 
            print("url")
            print("\(lhs.url) != \(rhs.url)")
            return false 
        }
        return true
    }
}

// MARK: Photo Equatable

extension Photo: Equatable {
    static func == (lhs: Photo, rhs: Photo) -> Bool {
        guard lhs.name == rhs.name else { 
            print("name")
            print("\(lhs.name) != \(rhs.name)")
            return false 
        }
        guard lhs.url == rhs.url else { 
            print("url")
            print("\(lhs.url) != \(rhs.url)")
            return false 
        }
        guard lhs.originalImageURL == rhs.originalImageURL else { 
            print("originalImageURL")
            print("\(lhs.originalImageURL) != \(rhs.originalImageURL)")
            return false 
        }
        guard lhs.originalImagePath == rhs.originalImagePath else { 
            print("originalImagePath")
            print("\(lhs.originalImagePath) != \(rhs.originalImagePath)")
            return false 
        }
        guard lhs.scaledPhotos == rhs.scaledPhotos else { 
            print("scaledPhotos")
            print("\(lhs.scaledPhotos) != \(rhs.scaledPhotos)")
            return false 
        }
        guard lhs.parents == rhs.parents else { 
            print("parents")
            print("\(lhs.parents) != \(rhs.parents)")
            return false 
        }
        guard lhs.aperture == rhs.aperture else { 
            print("aperture")
            print("\(lhs.aperture) != \(rhs.aperture)")
            return false 
        }
        guard lhs.apertureFormatted == rhs.apertureFormatted else { 
            print("apertureFormatted")
            print("\(lhs.apertureFormatted) != \(rhs.apertureFormatted)")
            return false 
        }
        guard lhs.cameraMake == rhs.cameraMake else { 
            print("cameraMake")
            print("\(lhs.cameraMake) != \(rhs.cameraMake)")
            return false 
        }
        guard lhs.cameraModel == rhs.cameraModel else { 
            print("cameraModel")
            print("\(lhs.cameraModel) != \(rhs.cameraModel)")
            return false 
        }
        guard lhs.copyright == rhs.copyright else { 
            print("copyright")
            print("\(lhs.copyright) != \(rhs.copyright)")
            return false 
        }
        guard lhs.dateTime == rhs.dateTime else { 
            print("dateTime")
            print("\(lhs.dateTime) != \(rhs.dateTime)")
            return false 
        }
        guard lhs.exposureTime == rhs.exposureTime else { 
            print("exposureTime")
            print("\(lhs.exposureTime) != \(rhs.exposureTime)")
            return false 
        }
        guard lhs.exposureTimeFormatted == rhs.exposureTimeFormatted else { 
            print("exposureTimeFormatted")
            print("\(lhs.exposureTimeFormatted) != \(rhs.exposureTimeFormatted)")
            return false 
        }
        guard lhs.fNumber == rhs.fNumber else { 
            print("fNumber")
            print("\(lhs.fNumber) != \(rhs.fNumber)")
            return false 
        }
        guard lhs.fNumberFormatted == rhs.fNumberFormatted else { 
            print("fNumberFormatted")
            print("\(lhs.fNumberFormatted) != \(rhs.fNumberFormatted)")
            return false 
        }
        guard lhs.focalLength == rhs.focalLength else { 
            print("focalLength")
            print("\(lhs.focalLength) != \(rhs.focalLength)")
            return false 
        }
        guard lhs.focalLengthFormatted == rhs.focalLengthFormatted else { 
            print("focalLengthFormatted")
            print("\(lhs.focalLengthFormatted) != \(rhs.focalLengthFormatted)")
            return false 
        }
        guard lhs.gps == rhs.gps else { 
            print("gps")
            print("\(lhs.gps) != \(rhs.gps)")
            return false 
        }
        guard lhs.height == rhs.height else { 
            print("height")
            print("\(lhs.height) != \(rhs.height)")
            return false 
        }
        guard lhs.imageDescription == rhs.imageDescription else { 
            print("imageDescription")
            print("\(lhs.imageDescription) != \(rhs.imageDescription)")
            return false 
        }
        guard lhs.isoSpeed == rhs.isoSpeed else { 
            print("isoSpeed")
            print("\(lhs.isoSpeed) != \(rhs.isoSpeed)")
            return false 
        }
        guard lhs.lensModel == rhs.lensModel else { 
            print("lensModel")
            print("\(lhs.lensModel) != \(rhs.lensModel)")
            return false 
        }
        guard lhs.location == rhs.location else { 
            print("location")
            print("\(lhs.location) != \(rhs.location)")
            return false 
        }
        guard lhs.meteringMode == rhs.meteringMode else { 
            print("meteringMode")
            print("\(lhs.meteringMode) != \(rhs.meteringMode)")
            return false 
        }
        guard lhs.meteringModeFormatted == rhs.meteringModeFormatted else { 
            print("meteringModeFormatted")
            print("\(lhs.meteringModeFormatted) != \(rhs.meteringModeFormatted)")
            return false 
        }
        guard lhs.modifiedDate == rhs.modifiedDate else { 
            print("modifiedDate")
            print("\(lhs.modifiedDate) != \(rhs.modifiedDate)")
            return false 
        }
        guard lhs.orientation == rhs.orientation else { 
            print("orientation")
            print("\(lhs.orientation) != \(rhs.orientation)")
            return false 
        }
        guard lhs.owner == rhs.owner else { 
            print("owner")
            print("\(lhs.owner) != \(rhs.owner)")
            return false 
        }
        guard lhs.shutterSpeed == rhs.shutterSpeed else { 
            print("shutterSpeed")
            print("\(lhs.shutterSpeed) != \(rhs.shutterSpeed)")
            return false 
        }
        guard lhs.shutterSpeedFormatted == rhs.shutterSpeedFormatted else { 
            print("shutterSpeedFormatted")
            print("\(lhs.shutterSpeedFormatted) != \(rhs.shutterSpeedFormatted)")
            return false 
        }
        guard lhs.width == rhs.width else { 
            print("width")
            print("\(lhs.width) != \(rhs.width)")
            return false 
        }
        guard lhs.keywords == rhs.keywords else { 
            print("keywords")
            print("\(lhs.keywords) != \(rhs.keywords)")
            return false 
        }
        guard lhs.people == rhs.people else { 
            print("people")
            print("\(lhs.people) != \(rhs.people)")
            return false 
        }
        guard lhs.next == rhs.next else { 
            print("next")
            print("\(lhs.next) != \(rhs.next)")
            return false 
        }
        guard lhs.previous == rhs.previous else { 
            print("previous")
            print("\(lhs.previous) != \(rhs.previous)")
            return false 
        }
        return true
    }
}

// MARK: ScaledPhoto Equatable

extension ScaledPhoto: Equatable {
    static func == (lhs: ScaledPhoto, rhs: ScaledPhoto) -> Bool {
        guard lhs.url == rhs.url else { 
            print("url")
            print("\(lhs.url) != \(rhs.url)")
            return false 
        }
        guard lhs.maxResolution == rhs.maxResolution else { 
            print("maxResolution")
            print("\(lhs.maxResolution) != \(rhs.maxResolution)")
            return false 
        }
        return true
    }
}
