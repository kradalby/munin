//
//  Statistics.swift
//  GalPackageDescription
//
//  Created by Kristoffer Andreas Dalby on 14/01/2018.
//

import Foundation

public struct Statistics {
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
}


