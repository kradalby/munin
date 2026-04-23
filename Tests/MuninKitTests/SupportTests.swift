import Foundation
import Testing

@testable import MuninKit

/// Sanity checks for the scaffolding used by the larger end-to-end tests.
/// Keeping these close to the helpers makes it obvious when the helpers
/// themselves regress (rather than chasing a symptom through a bigger
/// test).
@Suite(.serialized)
struct SupportTests {

  // MARK: - FilesystemSnapshot

  @Test func snapshotCapturesFilesSymlinksAndDirectories() throws {
    let root = try makeScratchDir()
    defer { try? FileManager.default.removeItem(atPath: root) }

    try writeFile("hello.txt", under: root, contents: "hello")
    try FileManager.default.createDirectory(
      atPath: root + "/sub", withIntermediateDirectories: true)
    try writeFile("sub/nested.txt", under: root, contents: "nested")
    try FileManager.default.createSymbolicLink(
      atPath: root + "/link", withDestinationPath: "hello.txt")

    let snapshot = try FilesystemSnapshot.capture(at: root)

    let hello = try #require(snapshot.entries["hello.txt"])
    #expect(hello.kind == .file)
    #expect(hello.size == 5)
    #expect(hello.sha256 != nil)

    let sub = try #require(snapshot.entries["sub"])
    #expect(sub.kind == .directory)

    let nested = try #require(snapshot.entries["sub/nested.txt"])
    #expect(nested.kind == .file)

    let link = try #require(snapshot.entries["link"])
    #expect(link.kind == .symlink)
    #expect(link.symlinkTarget == "hello.txt")
  }

  @Test func snapshotDiffClassifiesAddedRemovedChangedAndRewritten() throws {
    let root = try makeScratchDir()
    defer { try? FileManager.default.removeItem(atPath: root) }

    try writeFile("a.txt", under: root, contents: "a")
    try writeFile("b.txt", under: root, contents: "b")
    try writeFile("c.txt", under: root, contents: "c")

    let before = try FilesystemSnapshot.capture(at: root)

    // Add, remove, mutate.
    try writeFile("d.txt", under: root, contents: "d")
    try FileManager.default.removeItem(atPath: root + "/a.txt")
    try writeFile("b.txt", under: root, contents: "B!")

    // Rewrite c.txt with identical bytes but pushed-out mtime to exercise
    // the "rewrittenIdentical" path. Need a detectable delta, so sleep a
    // tick before writing — most filesystems have millisecond resolution
    // but HFS+ / some network FS truncate to seconds.
    let future = Date().addingTimeInterval(2)
    try writeFile("c.txt", under: root, contents: "c")
    try FileManager.default.setAttributes(
      [.modificationDate: future], ofItemAtPath: root + "/c.txt")

    let after = try FilesystemSnapshot.capture(at: root)
    let diff = before.diff(against: after)

    #expect(diff.added == ["d.txt"])
    #expect(diff.removed == ["a.txt"])
    #expect(diff.byteChanged == ["b.txt"])
    #expect(diff.rewrittenIdentical == ["c.txt"])
    #expect(diff.kindChanged == [])
    #expect(!diff.isEmpty)
  }

  @Test func snapshotDiffIsEmptyWhenNothingChanged() throws {
    let root = try makeScratchDir()
    defer { try? FileManager.default.removeItem(atPath: root) }

    try writeFile("a.txt", under: root, contents: "a")
    let snap1 = try FilesystemSnapshot.capture(at: root)
    let snap2 = try FilesystemSnapshot.capture(at: root)
    let diff = snap1.diff(against: snap2)
    #expect(diff.isEmpty)
  }

  // MARK: - SourceFixture

  @Test func sourceFixtureStagesSubsetAndCleansUp() throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let fm = FileManager.default
    #expect(fm.fileExists(atPath: fixture.sourceRoot + "/Misc"))
    #expect(fm.fileExists(atPath: fixture.sourceRoot + "/Misc/portrait_mm.jpeg"))
  }

  @Test func sourceFixtureMutationsAreIsolated() throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let fm = FileManager.default
    // Repo origin must remain untouched regardless of fixture mutation.
    let originPortrait = fixture.originPhoto("Misc/portrait_mm.jpeg")
    let originAttrsBefore = try fm.attributesOfItem(atPath: originPortrait)
    let originSizeBefore = (originAttrsBefore[.size] as? NSNumber)?.intValue ?? -1

    try fixture.removePhoto(inAlbum: "Misc", named: "portrait_mm.jpeg")
    #expect(!fm.fileExists(atPath: fixture.sourceRoot + "/Misc/portrait_mm.jpeg"))

    let originAttrsAfter = try fm.attributesOfItem(atPath: originPortrait)
    let originSizeAfter = (originAttrsAfter[.size] as? NSNumber)?.intValue ?? -2
    #expect(originSizeBefore == originSizeAfter)
    #expect(originSizeBefore > 0)
  }

  // MARK: - GalleryHarness

  @Test func galleryHarnessBuildsSmallAlbumEndToEnd() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "test")
    defer { harness.cleanup() }

    try await harness.build()
    let output = try harness.snapshotOutput()
    // Every leaf should live under either the named gallery folder
    // (`test/...`) or the shared `keywords/` folder that Munin writes at
    // output root level.
    for path in output.leafPaths {
      #expect(
        path.hasPrefix("test/") || path.hasPrefix("keywords/"),
        "unexpected top-level path \(path)")
    }
    // The gallery root must expose its index plus the shared stats and
    // locations files.
    #expect(output.entries.keys.contains("test/index.json"))
    #expect(output.entries.keys.contains("test/stats.json"))
    #expect(output.entries.keys.contains("test/locations.json"))
  }

  @Test func galleryHarnessInputIsUntouchedByBuild() async throws {
    let fixture = try SourceFixture.stage(albums: ["Misc"])
    defer { fixture.cleanup() }

    let harness = GalleryHarness(sourceRoot: fixture.sourceRoot, name: "test")
    defer { harness.cleanup() }

    let beforeSource = try harness.snapshotSource()
    try await harness.build()
    let afterSource = try harness.snapshotSource()
    let diff = beforeSource.diff(against: afterSource)
    let summary = """
      added=\(diff.added) removed=\(diff.removed) \
      byteChanged=\(diff.byteChanged) rewrittenIdentical=\(diff.rewrittenIdentical)
      """
    #expect(diff.isEmpty, "Source tree changed during build. \(summary)")
  }

  // MARK: - Helpers

  private func makeScratchDir() throws -> String {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("munin-support-\(UUID().uuidString)").path
    try FileManager.default.createDirectory(
      atPath: dir, withIntermediateDirectories: true)
    return dir
  }

  private func writeFile(_ relative: String, under root: String, contents: String) throws {
    let target = root + "/" + relative
    try FileManager.default.createDirectory(
      atPath: URL(fileURLWithPath: target).deletingLastPathComponent().path,
      withIntermediateDirectories: true)
    try Data(contents.utf8).write(to: URL(fileURLWithPath: target))
  }
}
