import Testing

@testable import MuninKit

@Suite
struct LocationDegreeTests {
  @Test func fromDecimal() {
    let expected = LocationDegree(
      degrees: 4, minutes: 37, seconds: 41.88000000000102
    )
    let actual = LocationDegree.fromDecimal(4.6283)
    #expect(actual == expected)
  }

  @Test func fromString() throws {
    let expected = LocationDegree(degrees: 4, minutes: 37, seconds: 41.88)
    let actual = try #require(LocationDegree.fromString("4, 37, 41.88"))
    #expect(actual == expected)
  }

  @Test func toDecimal() {
    let expected = 4.6283
    let actual = LocationDegree(degrees: 4, minutes: 37, seconds: 41.88).toDecimal()
    #expect(actual == expected)
  }
}
