//: Playground - noun: a place where people can play

import Cocoa

var str = "Hello, playground"

let fileURL = NSURL.fileURL(withPath: "/Users/kradalby/Library/Autosave Information/sample/nolocation/20180307-201421-IMG_6006_original.jpg")
if let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) {
    
    let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
    if let dict = imageProperties as? [String: Any] {
        print(dict)
    }
}
