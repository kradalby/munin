import Testing

@testable import MuninKit

@Suite
struct PathsTests {

  // MARK: - join

  @Test func joinBasicComponents() {
    #expect(Paths.join(["a", "b", "c"]) == "a/b/c")
  }

  @Test func joinEmptyArrayReturnsEmpty() {
    #expect(Paths.join([]) == "")
  }

  @Test func joinFiltersEmptyComponents() {
    #expect(Paths.join(["a", "", "b", ""]) == "a/b")
  }

  @Test func joinTrimsInternalSlashes() {
    #expect(Paths.join(["example/content/", "test"]) == "example/content/test")
    #expect(Paths.join(["example/content", "/test"]) == "example/content/test")
    #expect(Paths.join(["/a/", "/b/", "/c/"]) == "/a/b/c")
  }

  @Test func joinPreservesAbsoluteLeading() {
    #expect(Paths.join(["/tmp", "gallery"]) == "/tmp/gallery")
    #expect(Paths.join(["/tmp/", "gallery/", "out.json"]) == "/tmp/gallery/out.json")
  }

  @Test func joinRelativeStaysRelative() {
    #expect(Paths.join(["example", "content"]) == "example/content")
  }

  // MARK: - relative

  @Test func relativeStripsBasePrefix() {
    #expect(Paths.relative("hugin/root/2001/index.json", to: "hugin") == "root/2001/index.json")
    #expect(Paths.relative("content/root/index.json", to: "content") == "root/index.json")
  }

  @Test func relativeAcceptsMultiComponentBase() {
    #expect(Paths.relative("a/b/c/d.json", to: "a/b") == "c/d.json")
  }

  @Test func relativeIgnoresTrailingAndLeadingSlashesOnBase() {
    #expect(Paths.relative("hugin/root/a.json", to: "hugin/") == "root/a.json")
    #expect(Paths.relative("/out/hugin/root/a.json", to: "/out/hugin/") == "root/a.json")
  }

  @Test func relativeReturnsEmptyWhenPathEqualsBase() {
    #expect(Paths.relative("hugin", to: "hugin") == "")
  }

  /// The whole point of matching component-wise: a sibling directory whose
  /// name merely starts with the base must not be treated as being under it.
  @Test func relativeDoesNotMatchPartialComponent() {
    #expect(Paths.relative("hugin2/root/a.json", to: "hugin") == "hugin2/root/a.json")
    #expect(Paths.relative("huginx", to: "hugin") == "huginx")
  }

  @Test func relativeLeavesPathsOutsideBaseUnchanged() {
    #expect(Paths.relative("other/root/a.json", to: "hugin") == "other/root/a.json")
    #expect(Paths.relative("root/a.json", to: "hugin") == "root/a.json")
  }

  @Test func relativeWithEmptyBaseIsIdentity() {
    #expect(Paths.relative("hugin/root/a.json", to: "") == "hugin/root/a.json")
    #expect(Paths.relative("hugin/root/a.json", to: "/") == "hugin/root/a.json")
  }

  @Test func relativeDoesNotMixAbsoluteAndRelative() {
    #expect(Paths.relative("/hugin/root/a.json", to: "hugin") == "/hugin/root/a.json")
    #expect(Paths.relative("hugin/root/a.json", to: "/hugin") == "hugin/root/a.json")
  }

  @Test func relativeHandlesAbsolutePaths() {
    #expect(Paths.relative("/srv/gallery/root/a.json", to: "/srv/gallery") == "root/a.json")
  }

  @Test func relativePreservesNonASCIIComponents() {
    #expect(
      Paths.relative("hugin/root/2024/Håkon_har_nytt_/a.json", to: "hugin")
        == "root/2024/Håkon_har_nytt_/a.json")
  }

  // MARK: - stem / extension

  @Test func stemStripsExtension() {
    #expect(Paths.stem("/tmp/foo.jpg") == "foo")
    #expect(Paths.stem("foo.tar.gz") == "foo.tar")
    #expect(Paths.stem("foo") == "foo")
  }

  @Test func extractsExtensionSuffix() {
    #expect(Paths.extension("/tmp/foo.jpg") == "jpg")
    #expect(Paths.extension("foo.tar.gz") == "gz")
    #expect(Paths.extension("foo") == nil)
  }

  // MARK: - urlify

  @Test func urlifyReplacesSpaces() {
    #expect(Paths.urlify("2018-03-10 Alkmaar") == "2018-03-10_Alkmaar")
    #expect(Paths.urlify("no spaces") == "no_spaces")
    #expect(Paths.urlify("already_clean") == "already_clean")
  }
}
