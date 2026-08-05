import Foundation
import SystemPackage

extension CodingUserInfoKey {
  /// Gallery root (`Configuration.targetFolder`) that ``GalleryURL`` strips
  /// when encoding and restores when decoding.
  static let galleryRoot = CodingUserInfoKey(rawValue: "no.kradalby.munin.galleryRoot")!
}

/// A location Munin both writes to on disk and publishes in JSON.
///
/// Munin used a single string for both jobs, so every published URL carried
/// the name of `Configuration.targetFolder` — and a gallery only rendered
/// correctly if a web server happened to expose that exact directory name at
/// its root. Consumers had to hard-code the same name to compensate.
///
/// This type keeps the full on-disk path in memory, because writers, symlink
/// depth and cleanup all still need it, and strips the gallery root only when
/// encoding. What ships in JSON is therefore relative to the gallery root,
/// and a gallery can be served from any prefix.
///
/// The root travels through `Encoder`/`Decoder` `userInfo`; construct coders
/// via ``MuninJSON/encoder(galleryRoot:)`` and
/// ``MuninJSON/decoder(galleryRoot:)``. With no root configured the value
/// round-trips unchanged, which keeps model-level tests free of coder setup.
struct GalleryURL: Hashable, Sendable {
  /// Full path, rooted where Munin writes.
  var path: FilePath

  init(_ path: FilePath) {
    self.path = path
  }

  init(_ path: String) {
    self.path = FilePath(path)
  }

  var string: String {
    path.string
  }
}

extension GalleryURL: Comparable {
  static func < (lhs: GalleryURL, rhs: GalleryURL) -> Bool {
    lhs.path.string < rhs.path.string
  }
}

extension GalleryURL: CustomStringConvertible {
  var description: String {
    path.string
  }
}

extension GalleryURL: Codable {
  init(from decoder: Decoder) throws {
    let raw = try decoder.singleValueContainer().decode(String.self)
    let root = decoder.userInfo[.galleryRoot] as? String ?? ""

    // Re-root, so everything in memory is a usable on-disk path regardless
    // of how the JSON was written.
    self.path = FilePath(Paths.join([root, raw]))
  }

  func encode(to encoder: Encoder) throws {
    let root = encoder.userInfo[.galleryRoot] as? String ?? ""
    var container = encoder.singleValueContainer()
    try container.encode(Paths.relative(path.string, to: root))
  }
}
