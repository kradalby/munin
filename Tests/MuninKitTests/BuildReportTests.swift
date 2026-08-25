import Foundation
import Testing

@testable import MuninKit

/// Locks the `BuildReport` contract: `Gallery.build` swallows per-photo
/// failures, collects them on the returned report, and keeps producing the
/// rest of the tree's output so a single bad source doesn't abort a
/// tens-of-thousands-photo build.
@Suite(.serialized)
struct BuildReportTests {

  @Test func buildReportsNoFailuresOnHappyPath() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }

    let gallery = try await Gallery.load(ctx: harness.ctx)
    let report = try await gallery.build(ctx: harness.ctx, jsonOnly: false)

    #expect(report.hasFailures == false)
    #expect(report.failures.isEmpty)
    #expect(report.photosWritten > 0)
  }

  @Test func buildReportsCorruptSourceWithoutAbortingOthers() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }
    try fixture.plantCorruptPhoto(inAlbum: "Misc", named: "broken.jpg")

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot)
    defer { harness.cleanup() }

    let gallery = try await Gallery.load(ctx: harness.ctx)
    let report = try await gallery.build(ctx: harness.ctx, jsonOnly: false)

    #expect(report.hasFailures)
    #expect(report.failures.count == 1)
    let failure = try #require(report.failures.first)
    #expect(failure.photo == "broken")
    if case .imageOperationFailed(_, let op, _) = failure.error {
      #expect(op == "open")
    } else {
      Issue.record("Expected imageOperationFailed, got \(failure.error)")
    }

    // Reported, but not published: a source with no dimensions and no
    // thumbnails has nothing to symlink, and one missing `_original` is
    // enough to fail its album's whole download. `clean` also removes the
    // sidecar if an earlier run wrote one.
    #expect(
      !FileManager.default.fileExists(
        atPath: harness.outputGalleryRoot + "/Misc/broken.json"))
    #expect(
      !FileManager.default.fileExists(
        atPath: harness.outputGalleryRoot + "/Misc/broken_original.jpg"))

    // The other Misc photos still produced JSON metadata despite the
    // broken sibling — partial-failure tolerance, not abort-on-first.
    let otherPhotos = ["portrait_mm", "20180510-171752-IMG_7165", "test_special_chars"]
    for name in otherPhotos {
      let jsonPath = harness.outputGalleryRoot + "/Misc/\(name).json"
      #expect(
        FileManager.default.fileExists(atPath: jsonPath),
        "expected \(jsonPath) to exist")
    }
  }
}
