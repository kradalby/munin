import Foundation
import Testing

@testable import MuninKit

@Suite
struct UtilsTests {

  @Test func findAlbumByNameBehaviour() {
    // swiftlint:disable identifier_name
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

    #expect(findAlbumByName(name: "not_found", album: root) == nil)
    #expect(findAlbumByName(name: "root", album: root) == root)
    #expect(findAlbumByName(name: "child1_of_root", album: root) == child1_of_root)
    #expect(findAlbumByName(name: "child2_of_root", album: root) == child2_of_root)
    #expect(findAlbumByName(name: "child1_of_child1", album: root) == child1_of_child1)
    #expect(findAlbumByName(name: "child2_of_child1", album: root) == child2_of_child1)
    #expect(findAlbumByName(name: "child1_of_child2", album: root) == child1_of_child2)
    #expect(findAlbumByName(name: "child2_of_child2", album: root) == child2_of_child2)

    #expect(findAlbumByName(name: "not_found", albums: [root]) == nil)
    #expect(findAlbumByName(name: "root", albums: [root]) == root)
    #expect(findAlbumByName(name: "child1_of_root", albums: [root]) == child1_of_root)
    #expect(findAlbumByName(name: "child2_of_root", albums: [root]) == child2_of_root)
    #expect(findAlbumByName(name: "child1_of_child1", albums: [root]) == child1_of_child1)
    #expect(findAlbumByName(name: "child2_of_child1", albums: [root]) == child2_of_child1)
    #expect(findAlbumByName(name: "child1_of_child2", albums: [root]) == child1_of_child2)
    #expect(findAlbumByName(name: "child2_of_child2", albums: [root]) == child2_of_child2)

    #expect(
      findAlbumByName(name: "child2_of_child1", albums: [child1_of_root, child2_of_root])
        == child2_of_child1)
    #expect(
      findAlbumByName(name: "child1_of_child2", albums: [child1_of_root, child2_of_root])
        == child1_of_child2)

    #expect(
      findAlbumByName(name: "child1_of_child1", album: child1_of_root) == child1_of_child1)
    #expect(
      findAlbumByName(name: "child2_of_child1", album: child1_of_root) == child2_of_child1)
    #expect(
      findAlbumByName(name: "child1_of_child2", album: child2_of_root) == child1_of_child2)
    #expect(
      findAlbumByName(name: "child2_of_child2", album: child2_of_root) == child2_of_child2)

    #expect(findAlbumByName(name: "child1_of_child2", album: child1_of_root) == nil)
    #expect(findAlbumByName(name: "child2_of_child2", album: child1_of_root) == nil)
    #expect(findAlbumByName(name: "child1_of_child1", album: child2_of_root) == nil)
    #expect(findAlbumByName(name: "child2_of_child1", album: child2_of_root) == nil)
    // swiftlint:enable identifier_name
  }

  @Test func computeChangedPhotosTest() throws {
    // swiftlint:disable identifier_name
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

    #expect(in_root.numberOfPhotos(travers: true) == 3)
    #expect(in_root.numberOfAlbums(travers: true) == 6)

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

    #expect(out_root.numberOfPhotos(travers: true) == 0)
    #expect(out_root.numberOfAlbums(travers: true) == 6)

    let changes = try #require(computeChangedPhotos(input: in_root, output: out_root))
    #expect(changes.numberOfPhotos(travers: true) == 3)
    #expect(changes.numberOfAlbums(travers: true) == 3)
    // swiftlint:enable identifier_name
  }

  @Test func computeChangedPhotosAddedAlbum() throws {
    // swiftlint:disable identifier_name
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

    #expect(in_root.numberOfPhotos(travers: true) == 1)
    #expect(in_root.numberOfAlbums(travers: true) == 6)

    var out_root = Album(name: "root", path: "", parents: [])
    var out_child1_of_root = Album(name: "child1_of_root", path: "", parents: [])
    var out_child2_of_root = Album(name: "child2_of_root", path: "", parents: [])
    let out_child1_of_child1 = Album(name: "child1_of_child1", path: "", parents: [])
    let out_child2_of_child1 = Album(name: "child2_of_child1", path: "", parents: [])
    let out_child1_of_child2 = Album(name: "child1_of_child2", path: "", parents: [])

    out_child1_of_root.albums = [out_child1_of_child1, out_child2_of_child1]
    out_child2_of_root.albums = [out_child1_of_child2]
    out_root.albums = [out_child1_of_root, out_child2_of_root]

    #expect(out_root.numberOfPhotos(travers: true) == 0)
    #expect(out_root.numberOfAlbums(travers: true) == 5)

    let changes = try #require(computeChangedPhotos(input: in_root, output: out_root))
    prettyPrintAdded(changes)
    #expect(changes.numberOfPhotos(travers: true) == 1)
    #expect(changes.numberOfAlbums(travers: true) == 2)
    // swiftlint:enable identifier_name
  }

  @Test func computeChangedPhotosModifiedPhoto() throws {
    // swiftlint:disable identifier_name
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

    #expect(in_root.numberOfPhotos(travers: true) == 3)
    #expect(in_root.numberOfAlbums(travers: true) == 6)

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

    #expect(out_root.numberOfPhotos(travers: true) == 3)
    #expect(out_root.numberOfAlbums(travers: true) == 6)

    let changes = try #require(computeChangedPhotos(input: in_root, output: out_root))
    #expect(changes.numberOfPhotos(travers: true) == 2)
    #expect(changes.numberOfAlbums(travers: true) == 3)
    // swiftlint:enable identifier_name
  }
}
