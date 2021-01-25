import Config
import Foundation
import XCTest

@testable import MuninKit

final class UtilsTests: XCTestCase {

  func test() {
    XCTAssertEqual("test", "test")
  }

  func testFindAlbumByName() {
    var root = Album(name: "root", path: "", parents: [])
    var child1_of_root = Album(name: "child1_of_root", path: "", parents: [])
    var child2_of_root = Album(name: "child2_of_root", path: "", parents: [])
    let child1_of_child1 = Album(name: "child1_of_child1", path: "", parents: [])
    let child2_of_child1 = Album(name: "child2_of_child1", path: "", parents: [])
    let child1_of_child2 = Album(name: "child1_of_child2", path: "", parents: [])
    let child2_of_child2 = Album(name: "child2_of_child2", path: "", parents: [])

    child1_of_root.albums = [child1_of_child1, child2_of_child1]
    child2_of_root.albums = [child1_of_child2, child2_of_child2]
    root.albums = [child1_of_root, child2_of_root]

    XCTAssertNil(findAlbumByName(name: "not_found", album: root))
    XCTAssertEqual(findAlbumByName(name: "root", album: root), root)
    XCTAssertEqual(findAlbumByName(name: "child1_of_root", album: root), child1_of_root)
    XCTAssertEqual(findAlbumByName(name: "child2_of_root", album: root), child2_of_root)
    XCTAssertEqual(findAlbumByName(name: "child1_of_child1", album: root), child1_of_child1)
    XCTAssertEqual(findAlbumByName(name: "child2_of_child1", album: root), child2_of_child1)
    XCTAssertEqual(findAlbumByName(name: "child1_of_child2", album: root), child1_of_child2)
    XCTAssertEqual(findAlbumByName(name: "child2_of_child2", album: root), child2_of_child2)

    XCTAssertNil(findAlbumByName(name: "not_found", albums: [root]))
    XCTAssertEqual(findAlbumByName(name: "root", albums: [root]), root)
    XCTAssertEqual(findAlbumByName(name: "child1_of_root", albums: [root]), child1_of_root)
    XCTAssertEqual(findAlbumByName(name: "child2_of_root", albums: [root]), child2_of_root)
    XCTAssertEqual(findAlbumByName(name: "child1_of_child1", albums: [root]), child1_of_child1)
    XCTAssertEqual(findAlbumByName(name: "child2_of_child1", albums: [root]), child2_of_child1)
    XCTAssertEqual(findAlbumByName(name: "child1_of_child2", albums: [root]), child1_of_child2)
    XCTAssertEqual(findAlbumByName(name: "child2_of_child2", albums: [root]), child2_of_child2)

    XCTAssertEqual(
      findAlbumByName(name: "child2_of_child1", albums: [child1_of_root, child2_of_root]),
      child2_of_child1)
    XCTAssertEqual(
      findAlbumByName(name: "child1_of_child2", albums: [child1_of_root, child2_of_root]),
      child1_of_child2)

    XCTAssertEqual(
      findAlbumByName(name: "child1_of_child1", album: child1_of_root), child1_of_child1)
    XCTAssertEqual(
      findAlbumByName(name: "child2_of_child1", album: child1_of_root), child2_of_child1)
    XCTAssertEqual(
      findAlbumByName(name: "child1_of_child2", album: child2_of_root), child1_of_child2)
    XCTAssertEqual(
      findAlbumByName(name: "child2_of_child2", album: child2_of_root), child2_of_child2)

    XCTAssertNil(findAlbumByName(name: "child1_of_child2", album: child1_of_root))
    XCTAssertNil(findAlbumByName(name: "child2_of_child2", album: child1_of_root))
    XCTAssertNil(findAlbumByName(name: "child1_of_child1", album: child2_of_root))
    XCTAssertNil(findAlbumByName(name: "child2_of_child1", album: child2_of_root))

  }

  func testComputeChangedPhotos() {
    var in_root = Album(name: "root", path: "", parents: [])
    var in_child1_of_root = Album(name: "child1_of_root", path: "", parents: [])
    var in_child2_of_root = Album(name: "child2_of_root", path: "", parents: [])
    let in_child1_of_child1 = Album(name: "child1_of_child1", path: "", parents: [])
    let in_child2_of_child1 = Album(name: "child2_of_child1", path: "", parents: [])
    let in_child1_of_child2 = Album(name: "child1_of_child2", path: "", parents: [])
    var in_child2_of_child2 = Album(name: "child2_of_child2", path: "", parents: [])

    in_root.photos = [Photo(name: "photo4")]
    in_child1_of_root.photos = [Photo(name: "photo2")]
    in_child2_of_child2.photos = [Photo(name: "photo1")]

    in_child1_of_root.albums = [in_child1_of_child1, in_child2_of_child1]
    in_child2_of_root.albums = [in_child1_of_child2, in_child2_of_child2]
    in_root.albums = [in_child1_of_root, in_child2_of_root]

    XCTAssertEqual(in_root.numberOfPhotos(travers: true), 3)
    XCTAssertEqual(in_root.numberOfAlbums(travers: true), 6)

    var out_root = Album(name: "root", path: "", parents: [])
    var out_child1_of_root = Album(name: "child1_of_root", path: "", parents: [])
    var out_child2_of_root = Album(name: "child2_of_root", path: "", parents: [])
    let out_child1_of_child1 = Album(name: "child1_of_child1", path: "", parents: [])
    let out_child2_of_child1 = Album(name: "child2_of_child1", path: "", parents: [])
    let out_child1_of_child2 = Album(name: "child1_of_child2", path: "", parents: [])
    let out_child2_of_child2 = Album(name: "child2_of_child2", path: "", parents: [])

    out_child1_of_root.albums = [out_child1_of_child1, out_child2_of_child1]
    out_child2_of_root.albums = [out_child1_of_child2, out_child2_of_child2]
    out_root.albums = [out_child1_of_root, out_child2_of_root]

    XCTAssertEqual(out_root.numberOfPhotos(travers: true), 0)
    XCTAssertEqual(out_root.numberOfAlbums(travers: true), 6)

    let changes = computeChangedPhotos(input: in_root, output: out_root)
    XCTAssertEqual(changes!.numberOfPhotos(travers: true), 3)
    XCTAssertEqual(changes!.numberOfAlbums(travers: true), 3)
  }

  func testComputeChangedPhotosAddedAlbum() {
    var in_root = Album(name: "root", path: "", parents: [])
    var in_child1_of_root = Album(name: "child1_of_root", path: "", parents: [])
    var in_child2_of_root = Album(name: "child2_of_root", path: "", parents: [])
    let in_child1_of_child1 = Album(name: "child1_of_child1", path: "", parents: [])
    let in_child2_of_child1 = Album(name: "child2_of_child1", path: "", parents: [])
    let in_child1_of_child2 = Album(name: "child1_of_child2", path: "", parents: [])
    var in_child2_of_child2 = Album(name: "child2_of_child2", path: "", parents: [])

    in_child2_of_child2.photos = [Photo(name: "photo1")]

    in_child1_of_root.albums = [in_child1_of_child1, in_child2_of_child1]
    in_child2_of_root.albums = [in_child1_of_child2, in_child2_of_child2]
    in_root.albums = [in_child1_of_root, in_child2_of_root]

    XCTAssertEqual(in_root.numberOfPhotos(travers: true), 1)
    XCTAssertEqual(in_root.numberOfAlbums(travers: true), 6)

    var out_root = Album(name: "root", path: "", parents: [])
    var out_child1_of_root = Album(name: "child1_of_root", path: "", parents: [])
    var out_child2_of_root = Album(name: "child2_of_root", path: "", parents: [])
    let out_child1_of_child1 = Album(name: "child1_of_child1", path: "", parents: [])
    let out_child2_of_child1 = Album(name: "child2_of_child1", path: "", parents: [])
    let out_child1_of_child2 = Album(name: "child1_of_child2", path: "", parents: [])

    out_child1_of_root.albums = [out_child1_of_child1, out_child2_of_child1]
    out_child2_of_root.albums = [out_child1_of_child2]
    out_root.albums = [out_child1_of_root, out_child2_of_root]

    XCTAssertEqual(out_root.numberOfPhotos(travers: true), 0)
    XCTAssertEqual(out_root.numberOfAlbums(travers: true), 5)

    let changes = computeChangedPhotos(input: in_root, output: out_root)
    prettyPrintAdded(changes!)
    XCTAssertEqual(changes!.numberOfPhotos(travers: true), 1)
    XCTAssertEqual(changes!.numberOfAlbums(travers: true), 2)
  }

  func testComputeChangedPhotosModifiedPhoto() {
    var in_root = Album(name: "root", path: "", parents: [])
    var in_child1_of_root = Album(name: "child1_of_root", path: "", parents: [])
    var in_child2_of_root = Album(name: "child2_of_root", path: "", parents: [])
    let in_child1_of_child1 = Album(name: "child1_of_child1", path: "", parents: [])
    let in_child2_of_child1 = Album(name: "child2_of_child1", path: "", parents: [])
    let in_child1_of_child2 = Album(name: "child1_of_child2", path: "", parents: [])
    var in_child2_of_child2 = Album(name: "child2_of_child2", path: "", parents: [])

    let in_photo1 = Photo(
      name: "photo1", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [],
      modifiedDate: Date(timeIntervalSince1970: 1_610_482_000), parents: [])
    let in_photo2 = Photo(
      name: "photo2", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [],
      modifiedDate: Date(timeIntervalSince1970: 1_610_485_000), parents: [])
    let in_photo3 = Photo(
      name: "photo3", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [],
      modifiedDate: Date(timeIntervalSince1970: 1_610_485_000), parents: [])
    in_root.photos = [in_photo1]
    in_child1_of_root.photos = [in_photo2]
    in_child2_of_child2.photos = [in_photo3]

    in_child1_of_root.albums = [in_child1_of_child1, in_child2_of_child1]
    in_child2_of_root.albums = [in_child1_of_child2, in_child2_of_child2]
    in_root.albums = [in_child1_of_root, in_child2_of_root]

    XCTAssertEqual(in_root.numberOfPhotos(travers: true), 3)
    XCTAssertEqual(in_root.numberOfAlbums(travers: true), 6)

    var out_root = Album(name: "root", path: "", parents: [])
    var out_child1_of_root = Album(name: "child1_of_root", path: "", parents: [])
    var out_child2_of_root = Album(name: "child2_of_root", path: "", parents: [])
    let out_child1_of_child1 = Album(name: "child1_of_child1", path: "", parents: [])
    let out_child2_of_child1 = Album(name: "child2_of_child1", path: "", parents: [])
    let out_child1_of_child2 = Album(name: "child1_of_child2", path: "", parents: [])
    var out_child2_of_child2 = Album(name: "child2_of_child2", path: "", parents: [])

    let out_photo1 = Photo(
      name: "photo1", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [],
      modifiedDate: Date(timeIntervalSince1970: 1_610_482_000), parents: [])
    let out_photo2 = Photo(
      name: "photo2", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [],
      modifiedDate: Date(timeIntervalSince1970: 1_610_482_000), parents: [])
    let out_photo3 = Photo(
      name: "photo3", url: "", originalImageURL: "", originalImagePath: "", scaledPhotos: [],
      modifiedDate: Date(timeIntervalSince1970: 1_610_482_000), parents: [])
    out_root.photos = [out_photo1]
    out_child1_of_root.photos = [out_photo2]
    out_child2_of_child2.photos = [out_photo3]

    out_child1_of_root.albums = [out_child1_of_child1, out_child2_of_child1]
    out_child2_of_root.albums = [out_child1_of_child2, out_child2_of_child2]
    out_root.albums = [out_child1_of_root, out_child2_of_root]

    XCTAssertEqual(out_root.numberOfPhotos(travers: true), 3)
    XCTAssertEqual(out_root.numberOfAlbums(travers: true), 6)

    let changes = computeChangedPhotos(input: in_root, output: out_root)
    XCTAssertNotNil(changes)
    XCTAssertEqual(changes!.numberOfPhotos(travers: true), 2)
    XCTAssertEqual(changes!.numberOfAlbums(travers: true), 3)
  }

}
