import Foundation

struct Keyword: Hashable, Comparable {

    var name: String
    var url: String
    var photos: Set<Photo>
    
    init(name: String, path: String) {
        self.name = name
        self.url = joinPath(paths: path, "\(self.name).json")
        self.photos = []
    }
    
    enum CodingKeys: String, CodingKey {
        case name
        case url
        case photos
        case path
    }
}

extension Keyword: Encodable {
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)

        
        var photosContainer = container.nestedUnkeyedContainer(
            forKey: .photos)
        
        try photos.forEach {
            try photosContainer.encode($0.url)
        }
        
    }
}


extension Keyword: Decodable {
    init(from decoder: Decoder) throws
    {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try values.decode(String.self, forKey: .name)
        self.url = try values.decode(String.self, forKey: .url)

        
        
        // Here we will end up with the same picture twice in memory, is that a problem?
        var photosArray = try values.nestedUnkeyedContainer(forKey: .photos)
        var photos: Set<Photo> = Set<Photo>()
        while (!photosArray.isAtEnd) {
            let url = try photosArray.decode(String.self)
            if let photo = readAndDecodeJsonFile(Photo.self, atPath: url) {
                photos.insert(photo)
            }
        }
        self.photos = photos
    }
}

extension Keyword {
    static func <(lhs: Keyword, rhs: Keyword) -> Bool {
        return lhs.name < rhs.name
        
    }
    
    static func ==(lhs: Keyword, rhs: Keyword) -> Bool {
        guard lhs.name == rhs.name else { return false }
        guard lhs.url == rhs.url else { return false }
        guard lhs.photos == rhs.photos else { return false }

        return true
    }
    
    var hashValue: Int {
        return name.lengthOfBytes(using: .utf8) ^ url.lengthOfBytes(using: .utf8) &* 16777619
    }
    
}

extension Keyword {
    func write(config: GalleryConfiguration) -> Void {
        let fm = FileManager()
        let path = URL(fileURLWithPath: self.url).deletingLastPathComponent()
        do {
            try fm.createDirectory(at: path, withIntermediateDirectories: true)
            
            log.info("Writing metadata for \(type(of: self)) \(self.name)")
            let encoder = JSONEncoder()
            
            if let encodedData = try? encoder.encode(self) {
                do {
                    log.trace("Writing \(type(of: self)) metadata \(self.name) to \(self.url)")
                    try encodedData.write(to: URL(fileURLWithPath: self.url))
                } catch {
                    log.error("Could not write \(type(of: self)) \(self.name) to \(self.url) with error: \n\(error)")
                }
            }
        } catch {
            log.error("Failed creating directory \(path.absoluteString) with error: \n\(error)")
        }
    }
}

