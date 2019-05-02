//: Playground - noun: a place where people can play

import Cocoa

var str = "Hello, playground"

let fileURL = NSURL.fileURL(withPath: "/Users/kradalby/Downloads/20180629-114907-IMG_0995.jpeg")
if let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) {

    let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
    if let dict = imageProperties as? [String: Any] {
        print(dict)
    }
}
