import Foundation
import Testing

@testable import MuninKit

/// Direct unit tests for `Photo.==`.
///
/// The generated equality check has two hand-edited exclusions that the
/// rest of the system depends on for incremental rebuild correctness.
/// These tests lock them so an accidental Sourcery regeneration can't
/// silently regress the behaviour.
@Suite
struct PhotoEqualityTests {

  // MARK: - sourceHash is the primary change signal

  @Test func photosWithSameSourceHashButDifferentMtimeAreEqual() {
    var a = Self.minimalPhoto(modified: Self.anHourAgo)
    var b = Self.minimalPhoto(modified: Self.now)
    a.sourceHash = "cafebabe"
    b.sourceHash = "cafebabe"
    #expect(a == b)
  }

  @Test func photosWithDifferentSourceHashesAreNotEqual() {
    var a = Self.minimalPhoto()
    var b = Self.minimalPhoto()
    a.sourceHash = "aaaa"
    b.sourceHash = "bbbb"
    #expect(a != b)
  }

  @Test func photosWithOnlyOneHashedSideAreNotEqual() {
    // First build after an upgrade: disk JSON has no sourceHash (nil)
    // while a freshly-read Photo has one. Must compare unequal so the
    // diff forces a one-time re-encode of the tree.
    var a = Self.minimalPhoto()
    var b = Self.minimalPhoto()
    a.sourceHash = nil
    b.sourceHash = "deadbeef"
    #expect(a != b)
  }

  // MARK: - modifiedDate is no longer part of equality

  @Test func modifiedDateAloneDoesNotTriggerInequality() {
    var a = Self.minimalPhoto(modified: Self.anHourAgo)
    var b = Self.minimalPhoto(modified: Self.now)
    a.sourceHash = "h"
    b.sourceHash = "h"
    #expect(a == b, "touching mtime without changing bytes must not break equality")
  }

  // MARK: - Navigation fields remain excluded

  @Test func nextAndPreviousAreExcludedFromEquality() {
    var a = Self.minimalPhoto()
    var b = Self.minimalPhoto()
    a.sourceHash = "h"
    b.sourceHash = "h"
    a.next = "/some/next.json"
    a.previous = "/some/prev.json"
    b.next = "/other/next.json"
    b.previous = "/other/prev.json"
    #expect(
      a == b,
      "next/previous are derived navigation — shifting neighbours must not mark every photo as changed"
    )
  }

  // MARK: - Content-carrying fields still matter

  @Test func keywordChangesProduceInequality() {
    var a = Self.minimalPhoto()
    var b = Self.minimalPhoto()
    a.sourceHash = "h"
    b.sourceHash = "h"
    a.keywords = [KeywordPointer(name: "x", url: "/x")]
    b.keywords = [KeywordPointer(name: "y", url: "/y")]
    #expect(a != b)
  }

  @Test func scaledPhotosChangesProduceInequality() {
    var a = Self.minimalPhoto()
    var b = Self.minimalPhoto()
    a.sourceHash = "h"
    b.sourceHash = "h"
    a.scaledPhotos = [ScaledPhoto(url: "/x_180.jpg", maxResolution: 180)]
    b.scaledPhotos = [
      ScaledPhoto(url: "/x_180.jpg", maxResolution: 180),
      ScaledPhoto(url: "/x_340.jpg", maxResolution: 340),
    ]
    #expect(a != b)
  }

  // MARK: - encodingFingerprint catches config-only changes

  @Test func encodingFingerprintChangesProduceInequality() {
    // Same source bytes, same resolutions on the URL list — but the
    // encoded JPEG bytes differ because the config quality changed.
    // Without the fingerprint guard, diff would silently keep stale
    // output.
    var a = Self.minimalPhoto()
    var b = Self.minimalPhoto()
    a.sourceHash = "h"
    b.sourceHash = "h"
    a.encodingFingerprint = "q50_r180_r340"
    b.encodingFingerprint = "q90_r180_r340"
    #expect(a != b)
  }

  @Test func encodingFingerprintNilOnOneSideProducesInequality() {
    // First build after upgrade: on-disk JSON has no fingerprint while
    // the freshly-read Photo carries one. Must compare unequal to force
    // a one-time re-encode.
    var a = Self.minimalPhoto()
    var b = Self.minimalPhoto()
    a.sourceHash = "h"
    b.sourceHash = "h"
    a.encodingFingerprint = nil
    b.encodingFingerprint = "q90_r180_r340"
    #expect(a != b)
  }

  // MARK: - Fixtures

  private static let now = Date(timeIntervalSince1970: 1_710_000_000)
  private static let anHourAgo = Date(timeIntervalSince1970: 1_710_000_000 - 3600)

  private static func minimalPhoto(modified: Date = now) -> Photo {
    Photo(
      name: "p",
      url: "/out/p.json",
      originalImageURL: "/out/p_original.jpg",
      originalImagePath: "/in/p.jpg",
      scaledPhotos: [],
      modifiedDate: modified,
      parents: []
    )
  }
}
