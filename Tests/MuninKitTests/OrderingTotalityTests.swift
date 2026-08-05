import Foundation
import SystemPackage
import Testing

@testable import MuninKit

/// Everything Munin writes as a JSON array is produced by calling
/// `sorted()` on a `Set` — `Album.encode`'s `photos` and `albums`,
/// `Keyword.encode`'s `photos`, `Locations`' `locations`, the `keywords`
/// and `people` pointer lists. `Set` iteration order is a function of the
/// per-process randomised hash seed, and Swift's `sorted()` is stable, so
/// any pair of elements the comparator cannot order keeps whatever order
/// the `Set` handed it. The output then differs between two runs of the
/// same binary on the same input.
///
/// The invariant that makes those arrays a function of the input alone is
/// that each comparator is a *strict total order*. All five comparators
/// over Munin's own types are covered here — `Photo.<`, `Album.<`,
/// `Keyword.<`, `KeywordPointer.<`, `Location.<` — deliberately including
/// the ones whose ties no current caller can reach, so the coverage
/// boundary is the invariant rather than the list of call sites that
/// happen to exist today. These tests assert it in the two equivalent
/// forms that matter:
///
/// - trichotomy: for any two distinct values exactly one of `a < b`,
///   `b < a` holds;
/// - permutation invariance: `sorted()` yields the same sequence no
///   matter what order the elements arrived in — which is the property
///   the `Set` violates when the comparator ties.
///
/// Two triggers are covered, both of which occur with no path collision
/// anywhere and are therefore not addressed by the collision check:
///
/// - equal `dateTime` *and* equal `name` across two albums, which is what
///   a per-event copy of one shoot looks like once `Keyword` aggregates
///   the whole gallery with `flattenPhotos()`;
/// - names that are canonically equivalent but byte-distinct (NFC vs NFD
///   `Håkon`), which is what a macOS-synced tree hands a Linux host.
///   Swift's `String` comparison works on canonical equivalence, so
///   `"H\u{00e5}kon" < "Ha\u{030a}kon"` is false in both directions even
///   though the two are different files.
@Suite
struct OrderingTotalityTests {

  // MARK: - Generic checks

  /// Byte-level identity. Swift `String` equality is canonical, so two
  /// NFC/NFD spellings compare equal and an `[String]` comparison would
  /// silently accept a reordering of exactly the elements under test.
  private func key(_ path: FilePath) -> [UInt8] {
    Array(path.string.utf8)
  }

  private func key(_ url: GalleryURL) -> [UInt8] {
    key(url.path)
  }

  private func show(_ bytes: [UInt8]) -> String {
    // Escape non-ASCII so an NFC/NFD pair is visibly different in a
    // failure message rather than rendering as the same glyphs.
    bytes.map { $0 < 0x80 ? String(UnicodeScalar($0)) : String(format: "\\x%02x", $0) }
      .joined()
  }

  /// Report the *first* violation only. A tie in an n-element set shows up
  /// in most of its n! permutations, and one issue per permutation buries
  /// the signal.
  private func assertTrichotomy<T: Comparable>(
    _ values: [T],
    key: (T) -> [UInt8],
    label: String,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    var failure: String?
    outer: for i in values.indices {
      for j in values.indices where i < j {
        guard key(values[i]) != key(values[j]) else { continue }
        let forward = values[i] < values[j]
        let backward = values[j] < values[i]
        if forward == backward {
          failure = """
            \(label): "\(show(key(values[i])))" and "\(show(key(values[j])))" \
            are not ordered (a<b=\(forward), b<a=\(backward)); sorted() falls \
            back to Set iteration order, which is randomised per process
            """
          break outer
        }
      }
    }
    #expect(failure == nil, "\(failure ?? "")", sourceLocation: sourceLocation)
  }

  private func assertSortIsPermutationInvariant<T: Comparable>(
    _ values: [T],
    key: (T) -> [UInt8],
    label: String,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let reference = values.sorted().map(key)
    var failure: String?
    for permutation in permutations(of: values) {
      let got = permutation.sorted().map(key)
      if got != reference {
        failure = """
          \(label): sorting depends on arrival order — arriving as \
          \(permutation.map { self.show(key($0)) }) sorts to \
          \(got.map(show)) but the reference order is \(reference.map(show))
          """
        break
      }
    }
    #expect(failure == nil, "\(failure ?? "")", sourceLocation: sourceLocation)
  }

  private func permutations<T>(of values: [T]) -> [[T]] {
    guard values.count > 1 else { return [values] }
    var out: [[T]] = []
    for index in values.indices {
      var rest = values
      let picked = rest.remove(at: index)
      for tail in permutations(of: rest) {
        out.append([picked] + tail)
      }
    }
    return out
  }

  // MARK: - Fixtures

  private func photo(name: String, url: String, dateTime: Date?) -> Photo {
    var photo = Photo(
      name: name,
      url: url,
      originalImageURL: url,
      originalImagePath: url,
      scaledPhotos: [],
      modifiedDate: Date(timeIntervalSince1970: 0),
      parents: [])
    photo.dateTime = dateTime
    return photo
  }

  /// Photos that reach one `sorted()` call together and hit both tie
  /// triggers.
  private var tiedPhotos: [Photo] {
    let shared = Date(timeIntervalSince1970: 1_500_000_000)
    return [
      // Same capture second, same name, two albums: what `Keyword.photos`
      // aggregates when one shoot is filed under several events.
      photo(name: "shared", url: "out/root/AlbumOne/shared.json", dateTime: shared),
      photo(name: "shared", url: "out/root/AlbumTwo/shared.json", dateTime: shared),
      photo(name: "shared", url: "out/root/AlbumThree/shared.json", dateTime: shared),
      // Canonically equal, byte distinct, same album: two real files.
      photo(name: "H\u{00e5}kon", url: "out/root/Uni/H\u{00e5}kon.json", dateTime: shared),
      photo(name: "Ha\u{030a}kon", url: "out/root/Uni/Ha\u{030a}kon.json", dateTime: shared),
    ]
  }

  // MARK: - Photo

  @Test func photoOrderIsTotal() {
    assertTrichotomy(tiedPhotos, key: { self.key($0.url) }, label: "Photo.<")
  }

  @Test func photoSortDoesNotDependOnArrivalOrder() {
    assertSortIsPermutationInvariant(
      tiedPhotos, key: { self.key($0.url) }, label: "Photo.<")
  }

  /// Photos with no `dateTime` at all fall straight through to the name
  /// comparison, so they need the same tie-break.
  @Test func photoSortIsTotalWithoutDateTimes() {
    let values = [
      photo(name: "shared", url: "out/root/A/shared.json", dateTime: nil),
      photo(name: "shared", url: "out/root/B/shared.json", dateTime: nil),
      photo(name: "H\u{00e5}kon", url: "out/root/U/H\u{00e5}kon.json", dateTime: nil),
      photo(name: "Ha\u{030a}kon", url: "out/root/U/Ha\u{030a}kon.json", dateTime: nil),
    ]
    assertTrichotomy(values, key: { self.key($0.url) }, label: "Photo.< (no dateTime)")
    assertSortIsPermutationInvariant(
      values, key: { self.key($0.url) }, label: "Photo.< (no dateTime)")
  }

  /// The tie-break must be *last*: capture time still wins, then name.
  /// Without this the fix could silently reorder every existing gallery.
  @Test func photoOrderStillPrefersDateThenName() {
    let early = photo(
      name: "zzz", url: "out/root/A/zzz.json",
      dateTime: Date(timeIntervalSince1970: 1_000))
    let late = photo(
      name: "aaa", url: "out/root/A/aaa.json",
      dateTime: Date(timeIntervalSince1970: 2_000))
    #expect(early < late, "earlier capture time must sort first")

    let shared = Date(timeIntervalSince1970: 3_000)
    let nameA = photo(name: "aaa", url: "out/root/Z/aaa.json", dateTime: shared)
    let nameB = photo(name: "bbb", url: "out/root/A/bbb.json", dateTime: shared)
    #expect(nameA < nameB, "equal capture time must break on name, not url")

    let dated = photo(name: "aaa", url: "out/root/A/aaa.json", dateTime: shared)
    let undated = photo(name: "aaa", url: "out/root/A/aaa.json", dateTime: nil)
    #expect(dated < undated, "a photo with a capture time sorts before one without")
  }

  // MARK: - Album

  private var tiedAlbums: [Album] {
    [
      Album(name: "H\u{00e5}kon", path: "out/root/H\u{00e5}kon", parents: []),
      Album(name: "Ha\u{030a}kon", path: "out/root/Ha\u{030a}kon", parents: []),
      Album(name: "Zebra", path: "out/root/Zebra", parents: []),
    ]
  }

  @Test func albumOrderIsTotal() {
    assertTrichotomy(tiedAlbums, key: { self.key($0.url) }, label: "Album.<")
  }

  @Test func albumSortDoesNotDependOnArrivalOrder() {
    assertSortIsPermutationInvariant(
      tiedAlbums, key: { self.key($0.url) }, label: "Album.<")
  }

  @Test func albumOrderStillPrefersName() {
    let apple = Album(name: "Apple", path: "out/root/zzz", parents: [])
    let banana = Album(name: "Banana", path: "out/root/aaa", parents: [])
    #expect(apple < banana, "album order must stay by name, not by path")
  }

  // MARK: - KeywordPointer

  private var tiedPointers: [KeywordPointer] {
    [
      KeywordPointer(name: "H\u{00e5}kon", url: "out/keywords/H\u{00e5}kon.json"),
      KeywordPointer(name: "Ha\u{030a}kon", url: "out/keywords/Ha\u{030a}kon.json"),
      KeywordPointer(name: "Zebra", url: "out/keywords/Zebra.json"),
    ]
  }

  @Test func keywordPointerOrderIsTotal() {
    assertTrichotomy(tiedPointers, key: { self.key($0.url) }, label: "KeywordPointer.<")
  }

  @Test func keywordPointerSortDoesNotDependOnArrivalOrder() {
    assertSortIsPermutationInvariant(
      tiedPointers, key: { self.key($0.url) }, label: "KeywordPointer.<")
  }

  // MARK: - Keyword

  /// The aggregated pages themselves. `Gallery.build` writes them in
  /// `buildKeywordsFromAlbum(album:).sorted()` order, one file each, so a
  /// tie here decides which of two spellings owns a shared filename.
  private var tiedKeywords: [Keyword] {
    [
      Keyword(name: "H\u{00e5}kon", url: "out/keywords/H\u{00e5}kon.json"),
      Keyword(name: "Ha\u{030a}kon", url: "out/keywords/Ha\u{030a}kon.json"),
      Keyword(name: "Zebra", url: "out/keywords/Zebra.json"),
    ]
  }

  @Test func keywordOrderIsTotal() {
    assertTrichotomy(tiedKeywords, key: { self.key($0.url) }, label: "Keyword.<")
  }

  @Test func keywordSortDoesNotDependOnArrivalOrder() {
    assertSortIsPermutationInvariant(
      tiedKeywords, key: { self.key($0.url) }, label: "Keyword.<")
  }

  /// The tie-break must stay last: name still decides, as it did before.
  @Test func keywordOrderStillPrefersName() {
    let apple = Keyword(name: "Apple", url: "out/keywords/zzz.json")
    let banana = Keyword(name: "Banana", url: "out/keywords/aaa.json")
    #expect(apple < banana, "keyword order must stay by name, not by url")
  }

  // MARK: - Location

  private var tiedLocations: [Location] {
    let gps = GPS(altitude: 1, latitude: 2, longitude: 3)
    return [
      Location(url: "out/root/U/H\u{00e5}kon.json", gps: gps, scaledPhotos: []),
      Location(url: "out/root/U/Ha\u{030a}kon.json", gps: gps, scaledPhotos: []),
      Location(url: "out/root/U/Zebra.json", gps: gps, scaledPhotos: []),
    ]
  }

  @Test func locationOrderIsTotal() {
    assertTrichotomy(tiedLocations, key: { self.key($0.url) }, label: "Location.<")
  }

  @Test func locationSortDoesNotDependOnArrivalOrder() {
    assertSortIsPermutationInvariant(
      tiedLocations, key: { self.key($0.url) }, label: "Location.<")
  }
}
