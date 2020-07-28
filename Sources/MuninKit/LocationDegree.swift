import Foundation

struct LocationDegree: AutoEquatable {
  let degrees: Double
  let minutes: Double
  let seconds: Double

  static func fromString(_ str: String) -> LocationDegree? {
    let list = str.components(separatedBy: ",").compactMap {
      Double(
        $0.trimmingCharacters(in: .whitespacesAndNewlines)
      )
    }.filter { $0 <= 180 }

    if list.count != 3 {
      return nil
    }

    let (degrees, minutes, seconds) = (list[0], list[1], list[2])

    return LocationDegree(degrees: degrees, minutes: minutes, seconds: seconds)
  }

  static func fromDecimal(_ input: Double) -> LocationDegree {
    let degrees = floor(input)
    let minutes = floor(60 * (input - degrees))
    let seconds = 3600 * (input - degrees) - (60 * minutes)

    return LocationDegree(degrees: degrees, minutes: minutes, seconds: seconds)
  }

  func toDecimal() -> Double {
    return degrees + (minutes / 60) + (seconds / 3600)
  }
}
