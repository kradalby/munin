import Foundation
import Testing

@testable import MuninKit

/// EXIF `Date and Time (Original)` is a bare wall-clock string with no UTC
/// offset, so an unpinned formatter resolves it against the process timezone
/// — making every `dateTime` Munin writes, and therefore the incremental
/// cache and the output bytes, a function of the build host's `TZ`.
///
/// These tests establish the zone they run under rather than inheriting it.
/// Inheriting is worthless as a guard: every CI leg runs in UTC, so deleting
/// the pin from `parseExifDateTime` would keep them green. `Asia/Tokyo` is
/// nine hours the other way from a typical developer host, so neither a UTC
/// nor a western one passes by accident. Setting `NSTimeZone.default` is what
/// moves an unpinned `DateFormatter`; `setenv("TZ")` does not.
///
/// The override is process-global, hence `.serialized`.
///
/// Only the `timeZone` half is guarded. `Locale.current` cannot be tested on
/// Linux — swift-corelibs-foundation reports `en_001` whatever `LANG` says —
/// but the locale pin is still load-bearing on Darwin, where
/// `Locale(identifier: "th_TH")` is buddhist and reads the same string as
/// 1474-12-28.
///
/// The suite is skipped without `/usr/share/zoneinfo`, and that has to be
/// decided here: `TimeZone(identifier:)` is answered by ICU from embedded
/// data, so the `#require` below passes on a host with no tzdata and the next
/// line takes SIGILL. `TZDIR` does not help — the path is hardcoded in
/// libFoundationEssentials.so. Any distroless container hits this.
@Suite(
  .serialized,
  .enabled(
    if: FileManager.default.fileExists(atPath: "/usr/share/zoneinfo"),
    "no timezone database on this host"))
struct ExifDateTests {

  /// 2017-12-19T13:21:34Z — the capture time of
  /// `example/album/2017/2017-12-19 Aarhus/…IMG_5239.jpg`, which is what
  /// the committed baseline records.
  private let referenceInstant = Date(timeIntervalSince1970: 1_513_689_694)

  /// Run `body` with the process default timezone set to `identifier`.
  private func withDefaultTimeZone<R>(
    _ identifier: String, _ body: () -> R
  ) throws -> R {
    // Only catches an identifier ICU does not know; see the suite's
    // `.enabled(if:)` for the tzdata case.
    let zone = try #require(
      TimeZone(identifier: identifier), "unknown timezone identifier")
    let previous = NSTimeZone.default
    NSTimeZone.default = zone
    defer { NSTimeZone.default = previous }
    return body()
  }

  @Test func exifDateTimeIsParsedAsUTCRegardlessOfHostTimeZone() throws {
    let parsed = try withDefaultTimeZone("Asia/Tokyo") {
      parseExifDateTime("2017:12:19 13:21:34")
    }
    #expect(
      parsed == referenceInstant,
      """
      EXIF capture time resolved against the host timezone instead of UTC: \
      got \(String(describing: parsed)), want \(referenceInstant). The same \
      photo would get a different dateTime on every host.
      """)
  }

  /// The pin has to survive a zone whose *date* differs, not only its clock:
  /// at 00:30 in Tokyo it is still the previous day in UTC.
  @Test func exifDateTimeIsParsedAsUTCAcrossADateBoundary() throws {
    let parsed = try withDefaultTimeZone("Asia/Tokyo") {
      parseExifDateTime("2018:05:11 00:30:00")
    }
    // 2018-05-11T00:30:00Z. Under Tokyo the same string is
    // 2018-05-10T15:30:00Z.
    #expect(parsed == Date(timeIntervalSince1970: 1_525_998_600))
  }

  /// A fixed `dateFormat` also needs a fixed locale: a host whose default
  /// calendar is not Gregorian reinterprets `yyyy` against that calendar
  /// (a Buddhist-calendar locale reads `2017` as 1474 CE). The parse is
  /// checked here under an established zone, which is the half of the pin
  /// a test can establish — swift-corelibs-foundation caches
  /// `Locale.current` from the environment at first use and offers no
  /// supported way to move it mid-process, so a mutation that deleted
  /// only `formatter.locale` would survive this suite. It is checked in
  /// CI the only way available: every leg runs a Gregorian locale, so the
  /// pin is what keeps a non-Gregorian *user* host producing the same
  /// bytes.
  @Test func exifDateTimeParsingIgnoresTheHostCalendar() throws {
    let parsed = try withDefaultTimeZone("Asia/Tokyo") {
      parseExifDateTime("2018:05:10 17:17:52")
    }
    #expect(parsed != nil)
    #expect(parsed == Date(timeIntervalSince1970: 1_525_972_672))
  }

  @Test func malformedExifDateTimeIsRejected() throws {
    try withDefaultTimeZone("Asia/Tokyo") {
      #expect(parseExifDateTime("") == nil)
      #expect(parseExifDateTime("2018-05-10T17:17:52Z") == nil)
      #expect(parseExifDateTime("not a date") == nil)
    }
  }

  /// The override the tests above rely on has to actually reach a
  /// `DateFormatter`, or they would pass against a reverted parser and
  /// nobody would notice. This is the same unpinned formatter
  /// `parseExifDateTime` would be if its two pinning lines were deleted;
  /// if this ever stops resolving against the established zone, the
  /// guard above has quietly become decoration again.
  @Test func theEstablishedTimeZoneReachesAnUnpinnedFormatter() throws {
    let unpinned = try withDefaultTimeZone("Asia/Tokyo") { () -> Date? in
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
      return formatter.date(from: "2017:12:19 13:21:34")
    }
    #expect(
      unpinned == referenceInstant.addingTimeInterval(-9 * 3600),
      """
      an unpinned DateFormatter did not resolve against the established \
      zone (got \(String(describing: unpinned))), so the timezone tests in \
      this suite no longer prove anything
      """)
  }
}
