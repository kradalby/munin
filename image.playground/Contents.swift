//: Playground - noun: a place where people can play

import Cocoa

var str = "Hello, playground"

let fileURL = URL(fileURLWithPath: "/Users/kradalby/Desktop/20181026-144836-IMG_0127.jpg")
if let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) {
  let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil)
  if let dict = imageProperties as? [String: Any] {
    print(dict)
  }
}
