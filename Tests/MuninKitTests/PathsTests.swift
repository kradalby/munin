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
