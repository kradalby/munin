import Config
import XCTest

@testable import MuninKit

final class LocationDegreeTests: XCTestCase {
  func test() {
    // This is an example of a functional test case.
    // Use XCTAssert and related functions to verify your tests produce the correct
    // results.
    XCTAssertEqual("test", "test")
  }

  func testLocationDegreeFromDecimal() {
    let expected = LocationDegree(
      degrees: 4, minutes: 37, seconds: 41.88000000000102
    )

    let actual = LocationDegree.fromDecimal(4.6283)

    XCTAssertEqual(actual, expected)
  }

  func testLocationDegreeFromString() {
    let expected = LocationDegree(degrees: 4, minutes: 37, seconds: 41.88)

    if let actual = LocationDegree.fromString("4, 37, 41.88") {
      XCTAssertEqual(actual, expected)
    } else {
      XCTFail("Failed to convert string to LocationDegree")
    }

  }

  func testLocationDegreeToDecimal() {
    let expected = 4.6283

    let actual = LocationDegree(degrees: 4, minutes: 37, seconds: 41.88).toDecimal()

    XCTAssertEqual(actual, expected)
  }
}
