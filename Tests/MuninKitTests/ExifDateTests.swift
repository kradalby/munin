import Foundation
import Testing

@testable import MuninKit

/// EXIF `Date and Time (Original)` is a bare wall-clock string with no UTC
/// offset. Foundation resolves such a string against the process's default
/// timezone unless the formatter is told otherwise, so an unpinned
/// formatter makes every `dateTime` Munin writes — and therefore
/// `Photo.==`, the whole incremental cache, and the output bytes — a
/// function of the `TZ` of whichever host happened to run the build.
///
/// That is the same class of unpinned input as source mtimes, which
/// `scripts/normalise-mtimes.sh` exists to eliminate: the committed
/// `example/content` baseline is only reproducible because
/// `scripts/smoke-static.sh` runs `env -i` inside a busybox image that has
/// no timezone database at all, and Foundation falls back to UTC. Anyone
/// regenerating that baseline outside UTC would commit a tree CI could
/// never reproduce.
///
/// These tests therefore *establish* the timezone they run under instead
/// of inheriting it. Inheriting it is worthless as a guard: every CI leg
/// runs in UTC, so with the host's zone left alone, deleting both pinning
/// lines from `parseExifDateTime` keeps all of this green. Setting
/// `NSTimeZone.default` is what moves an unpinned `DateFormatter`
/// (`setenv("TZ")` + `tzset()` does not — it moves `TimeZone.current`
/// while a freshly created formatter keeps resolving against the old
/// default), so with the override in place the reverted parser fails here
/// in any environment, UTC hosts included.
///
/// The override is process-global, hence `.serialized` and a window one
/// call wide. Nothing else in Munin reads it: `parseExifDateTime` is the
/// only `DateFormatter` in the package, and `MuninJSON`'s `.iso8601`
/// strategy formats in GMT regardless.
///
/// Only the `timeZone` half is guarded here. The `locale` pin cannot be
/// tested on Linux at all: swift-corelibs-foundation does not derive
/// `Locale.current` from the environment — it reports `en_001`/gregorian
/// whatever `LANG` and `LC_ALL` say — so deleting that line changes
/// nothing here, and no CI leg with a locale set would catch it either.
/// It is still load-bearing, just for Darwin: `Locale(identifier:
/// "th_TH")` is buddhist and reads `2017:12:19 13:21:34` as 1474-12-28,
/// so a Mac whose default calendar is not Gregorian needs the pin.
@Suite(.serialized)
struct ExifDateTests {

  /// 2017-12-19T13:21:34Z — the capture time of
  /// `example/album/2017/2017-12-19 Aarhus/…IMG_5239.jpg`, which is what
  /// the committed baseline records.
  private let referenceInstant = Date(timeIntervalSince1970: 1_513_689_694)

  /// Run `body` with the process default timezone set to `identifier`,
  /// restoring the previous default afterwards.
  ///
  /// `Asia/Tokyo` (UTC+9, no DST) is used throughout: nine hours off UTC
  /// in the opposite direction from the western zones a developer host is
  /// likely to be in, so neither a UTC host nor a US/European one can
  /// pass by accident.
  private func withDefaultTimeZone<R>(
    _ identifier: String, _ body: () -> R
  ) throws -> R {
    let zone = try #require(
      TimeZone(identifier: identifier),
      "no timezone database on this host, so this test cannot establish a zone")
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

  /// The pin has to survive a zone whose *date* differs from UTC's, not
  /// only its clock: at 00:30 Tokyo time it is still the previous day in
  /// UTC, so a formatter that resolves against Tokyo reports an instant a
  /// calendar day away from the one the baseline records.
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
