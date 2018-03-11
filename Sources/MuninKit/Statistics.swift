//
//  Statistics.swift
//  GalPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 14/01/2018.
//

import Foundation

public struct Statistics: Codable {
    var originalPhotos: Int
    var writtenPhotos: Int
    var albums: Int
    var keywords: Int
    var people: Int
    
    init(gallery: Gallery) {
        self.originalPhotos = gallery.input.numberOfPhotos(travers: true)
        self.albums = gallery.input.numberOfAlbums(travers: true)

        self.writtenPhotos = self.originalPhotos * gallery.config.resolutions.count
        
        self.keywords = gallery.input.keywords.count
        self.people = gallery.input.people.count
    }
    
    public func toString() -> String {
        return """
        Gallery contains:
        \t\(self.originalPhotos) original photos
        \t\(self.albums) albums
        \t\(self.keywords) keywords
        \t\(self.people) people
        
        \t\(self.writtenPhotos) photos has been encoded
        """
    }
    
    public func write(config: GalleryConfiguration) -> Void {
        log.info("Writing stats")
        let fileURL = NSURL.fileURL(withPath: joinPath(paths: config.outputPath, config.name, "stats.json"))

        let encoder = JSONEncoder()
        
        if let encodedData = try? encoder.encode(self) {
            do {
                log.trace("Writing statistics to json to \(fileURL.path)")
                try encodedData.write(to: URL(fileURLWithPath: fileURL.path))
            } catch {
                log.error("Could not write statistics json to \(fileURL.path) with error: \n\(error)")
            }
        }
    }
}


