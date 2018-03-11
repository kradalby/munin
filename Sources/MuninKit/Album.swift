//
//  Album.swift
//  g
//
//  Created by Kristoffer Andreas Dalby on 25/12/2017.
//

import Foundation

struct Album: Hashable, Comparable {
    var name: String
    var url: String
    var path: String
    var photos: Set<Photo>
    var albums: Set<Album>
    var keywords: Set<String>
    var people: Set<String>
    
    
    init(name: String, path: String) {
        self.name = name
        self.path = path
        self.url = joinPath(paths: path, "index.json")
        self.photos = []
        self.albums = []
        self.keywords = Set()
        self.people = Set()
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case url
        case path
        case photos
        case albums
        case keywords
        case people
    }
    
}

extension Album: Encodable {
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encode(path, forKey: .path)
        try container.encode(keywords, forKey: .keywords)
        try container.encode(people, forKey: .people)
        
        var photosContainer = container.nestedUnkeyedContainer(
            forKey: .photos)
        
        try photos.forEach {
            try photosContainer.encode($0.url)
        }
        
        var albumsContainer = container.nestedUnkeyedContainer(
            forKey: .albums)
        
        try albums.forEach {
            try albumsContainer.encode($0.url)
        }
        
        //        var keywordsContainer = container.nestedUnkeyedContainer(
        //            forKey: .keywords)
        
        //        try keywords.forEach {
        //            try keywordsContainer.encode($0.url)
        //        }
        //
        //        var peopleContainer = container.nestedUnkeyedContainer(
        //            forKey: .people)
        //
        //        try people.forEach {
        //            try peopleContainer.encode($0.url)
        //        }
        
    }
}


extension Album: Decodable {
    init(from decoder: Decoder) throws
    {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try values.decode(String.self, forKey: .name)
        self.url = try values.decode(String.self, forKey: .url)
        self.path = try values.decode(String.self, forKey: .path)
        self.keywords = try values.decode(Set<String>.self, forKey: .keywords)
        self.people = try values.decode(Set<String>.self, forKey: .people)
        
        
        //        self.photos = try values.decode([Photo].self, forKey: .photos)
        //        self.albums = try values.decode([Album].self, forKey: .albums)
        
        var photosArray = try values.nestedUnkeyedContainer(forKey: .photos)
        var photos: Set<Photo> = Set<Photo>()
        while (!photosArray.isAtEnd) {
            let url = try photosArray.decode(String.self)
            if let photo = readAndDecodeJsonFile(Photo.self, atPath: url) {
                photos.insert(photo)
            }
        }
        self.photos = photos
        
        var albumsArray = try values.nestedUnkeyedContainer(forKey: .albums)
        var albums: Set<Album> = Set<Album>()
        while (!albumsArray.isAtEnd) {
            let url = try albumsArray.decode(String.self)
            if let album = readAndDecodeJsonFile(Album.self, atPath: url) {
                albums.insert(album)
            }
        }
        self.albums = albums
        
        //        var keywordsArray = try values.nestedUnkeyedContainer(forKey: .keywords)
        //        var keywords: Set<Keyword> = Set<Keyword>()
        //        while (!keywordsArray.isAtEnd) {
        //            let url = try keywordsArray.decode(String.self)
        //            if let keyword = readAndDecodeJsonFile(Keyword.self, atPath: url) {
        //                keywords.insert(keyword)
        //            }
        //        }
        //        self.keywords = keywords
        //
        //        var peopleArray = try values.nestedUnkeyedContainer(forKey: .people)
        //        var people: Set<Keyword> = Set<Keyword>()
        //        while (!peopleArray.isAtEnd) {
        //            let url = try peopleArray.decode(String.self)
        //            if let person = readAndDecodeJsonFile(Keyword.self, atPath: url) {
        //                people.insert(person)
        //            }
        //        }
        //        self.people = people
    }
}

extension Album {
    public func write(config: GalleryConfiguration) -> Void {
        let fm = FileManager()
        do {
            try fm.createDirectory(at: URL(fileURLWithPath: self.path), withIntermediateDirectories: true)
            
            log.info("Writing metadata for album \(self.name)")
            let encoder = JSONEncoder()
            if #available(OSX 10.12, *) {
                encoder.dateEncodingStrategy = .iso8601
            }
            
            if let encodedData = try? encoder.encode(self) {
                do {
                    log.trace("Writing album metadata \(self.name) to \(self.url)")
                    try encodedData.write(to: URL(fileURLWithPath: self.url))
                } catch {
                    log.error("Could not write album \(self.name) to \(self.url) with error: \n\(error)")
                }
            }
            
            for album in self.albums {
                album.write(config: config)
            }
            
            for photo in self.photos {
                concurrentQueue.async {
                    concurrentPhotoEncodeGroup.enter()
                    photo.write(config: config)
                    concurrentPhotoEncodeGroup.leave()
                }
            }
            
            
        } catch {
            log.error("Failed creating directory \(self.path) with error: \n\(error)")
        }
    }
    
    public func destroy(config: GalleryConfiguration) -> Void {
//        let fm = FileManager()
        
        for photo in self.photos {
            photo.destroy(config: config)
        }
        
        
    }
    
    func copyWithoutChildren() -> Album {
        var newAlbum = Album(name: self.name, path: self.path)
        newAlbum.url = self.url
        newAlbum.photos = []
        newAlbum.albums = []
        newAlbum.keywords = self.keywords
        newAlbum.people = self.people
        
        return newAlbum
    }
}

extension Album {
    static func ==(lhs: Album, rhs: Album) -> Bool {
        guard lhs.name == rhs.name else { return false }
        guard lhs.url == rhs.url else { return false }
        guard lhs.path == rhs.path else { return false }
        guard lhs.photos == rhs.photos else { return false }
        guard lhs.albums == rhs.albums else { return false }
        guard lhs.keywords == rhs.keywords else { return false }
        guard lhs.people == rhs.people else { return false }
        return true
    }
    
    static func <(lhs: Album, rhs: Album) -> Bool {
        return lhs.name < rhs.name
    }
    
    var hashValue: Int {
        return name.lengthOfBytes(using: .utf8) ^ url.lengthOfBytes(using: .utf8) &* 16777619
    }
    

}

extension Album {
    func numberOfPhotos(travers: Bool) -> Int {
        if travers {
            return self.albums.map({$0.numberOfPhotos(travers: travers)}).reduce(0, +) + photos.count
        }
        return photos.count
    }
    
    func numberOfAlbums(travers: Bool) -> Int {
        if travers {
            return self.albums.map({$0.numberOfAlbums(travers: travers)}).reduce(0, +) + albums.count
        }
        return albums.count
    }
    
    func isEmpty(travers: Bool) -> Bool {
        for album in self.albums {
            if !album.isEmpty(travers: travers) {
                return false
            }
        }
        return self.photos.isEmpty
    }
}

func readStateFromInputDirectory(atPath: String, outPath: String, name: String, config: GalleryConfiguration) -> Album {
    log.info("Creating album from path: \(joinPath(paths: atPath))")
    let fm = FileManager()
    var album = Album(name: name, path: joinPath(paths: outPath, urlifyName(name)))
    if let files = try? fm.contentsOfDirectory(atPath: joinPath(paths: atPath)) {
        for element in files {
            var isDirectory: ObjCBool = ObjCBool(false)
            let exists = fm.fileExists(atPath: joinPath(paths: atPath, element), isDirectory: &isDirectory)
            
            if exists && isDirectory.boolValue {

//                concurrentPhotoReadDirectoryGroup.enter()
//                concurrentQueue.async {
                    let childAlbum = readStateFromInputDirectory(atPath: joinPath(paths: atPath, element), outPath: joinPath(paths: outPath, name), name: element, config: config)
                    album.albums.insert(childAlbum)
                    album.keywords = album.keywords.union(childAlbum.keywords)
                    album.people = album.people.union(childAlbum.people)
//                }
//                concurrentPhotoReadDirectoryGroup.leave()


            } else if exists {
                if let fileNameWithoutExtension = fileNameWithoutExtension(atPath: joinPath(paths: atPath, element)),
                    let fileExtension = fileExtension(atPath: joinPath(paths: atPath, element)) {
                    if config.fileExtentions.contains(fileExtension) {
//                        concurrentQueue.async {
//                            concurrentPhotoReadDirectoryGroup.enter()
                            if let photo = readPhotoFromPath(atPath: joinPath(paths: atPath, element), outPath: joinPath(paths: outPath, urlifyName(name)), name: fileNameWithoutExtension, fileExtension: fileExtension, config: config) {
                                album.photos.insert(photo)
                                album.keywords = album.keywords.union(photo.keywords)
                                album.people = album.people.union(photo.people)
                            }
//                            concurrentPhotoReadDirectoryGroup.leave()
//                        }
                        
                    } else {
                        log.warning("File found, but it was not a photo, path: \(joinPath(paths: atPath, element))")
                    }
                }
            }
        }
//        concurrentPhotoReadDirectoryGroup.wait()

    }
    return album
}





func readStateFromOutputDirectory(indexFileAtPath: String) -> Album? {
    return readAndDecodeJsonFile(Album.self, atPath: indexFileAtPath)
}
