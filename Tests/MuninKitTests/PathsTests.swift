import XCTest

@testable import MuninKit

final class PathsTests: XCTestCase {

  // MARK: - join

  func testJoinBasicComponents() {
    XCTAssertEqual(Paths.join(["a", "b", "c"]), "a/b/c")
  }

  func testJoinEmptyArrayReturnsEmpty() {
    XCTAssertEqual(Paths.join([]), "")
  }

  func testJoinFiltersEmptyComponents() {
    XCTAssertEqual(Paths.join(["a", "", "b", ""]), "a/b")
  }

  func testJoinTrimsInternalSlashes() {
    XCTAssertEqual(Paths.join(["example/content/", "test"]), "example/content/test")
    XCTAssertEqual(Paths.join(["example/content", "/test"]), "example/content/test")
    XCTAssertEqual(Paths.join(["/a/", "/b/", "/c/"]), "/a/b/c")
  }

  func testJoinPreservesAbsoluteLeading() {
    XCTAssertEqual(Paths.join(["/tmp", "gallery"]), "/tmp/gallery")
    XCTAssertEqual(Paths.join(["/tmp/", "gallery/", "out.json"]), "/tmp/gallery/out.json")
  }

  func testJoinRelativeStaysRelative() {
    XCTAssertEqual(Paths.join(["example", "content"]), "example/content")
  }

  // MARK: - stem / extension

  func testStemStripsExtension() {
    XCTAssertEqual(Paths.stem("/tmp/foo.jpg"), "foo")
    XCTAssertEqual(Paths.stem("foo.tar.gz"), "foo.tar")
    XCTAssertEqual(Paths.stem("foo"), "foo")
  }

  func testExtensionExtractsSuffix() {
    XCTAssertEqual(Paths.extension("/tmp/foo.jpg"), "jpg")
    XCTAssertEqual(Paths.extension("foo.tar.gz"), "gz")
    XCTAssertNil(Paths.extension("foo"))
  }

  // MARK: - urlify

  func testUrlifyReplacesSpaces() {
    XCTAssertEqual(Paths.urlify("2018-03-10 Alkmaar"), "2018-03-10_Alkmaar")
    XCTAssertEqual(Paths.urlify("no spaces"), "no_spaces")
    XCTAssertEqual(Paths.urlify("already_clean"), "already_clean")
  }
}
