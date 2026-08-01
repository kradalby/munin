# Munin — future work

Items that were explicitly out of scope for the Swift 6.3.1 modernization but
are known and tracked here. Loosely ordered by impact / cost.

---

## 3. Streaming read pipeline

`readStateFromInputDirectory` currently returns a fully-realized `Album`.
A streaming variant returning `AsyncThrowingStream<Photo, Error>` would
allow write-as-you-read for very large galleries, significantly reducing
peak memory during the first full build of a big tree.

---

## 4. `SwiftExif` replacement

`kradalby/SwiftExif` 0.1.0 covers Munin's needs: a Sendable typed
result from `Image.parse(at:)`, an `IptcFields` struct that retires
the old `[String: Any]` IPTC dict, and a tagged release that lets us
drop the SHA pin. Replacement is no longer urgent — this section
tracks the cases where it might still be worth it:

- A pure-Swift EXIF / IPTC reader would let us drop the libexif C
  dependency entirely. None widely-used existed at the time of this
  modernization; a fork under `swiftlang` / `apple` would be
  preferable if one emerges.
- A minimal in-tree IPTC reader covering only the fields Munin
  actually uses (Keywords, City, Province/State, Country Code,
  Country Name) would shrink the dependency surface further. Most of
  SwiftExif's API is unused by Munin.

The remaining functional gaps, regardless of replacement:

- SwiftExif 0.1.0 still can't distinguish "no EXIF present" from "EXIF
  present but corrupt" — both surface as an empty `ExifResult`.
  Distinguishing the two would let `Photo+Read` log "image X had
  unreadable EXIF" instead of silently degrading.
- **A photo with exactly one IPTC keyword loses it.**
  `IptcData.toDict()` stores a lone occurrence of a repeatable field as
  `String` and only promotes it to `[String]` on the second occurrence,
  while `makeIptcFields` reads `dict["Keywords"] as? [String] ?? []`. So a
  one-keyword photo arrives at Munin with no keywords at all and appears on
  no keyword page. Found while building the IPTC fixtures for
  `OutputPathCollisionTests`, which is why those splice two keywords per
  photo. Upstream fix is one line (`as? [String] ?? (as? String).map { [$0] }`);
  a workaround in `Photo+Read` would have to reach into `iptc.extras`.

---

## 6. Richer logging

`swift-log` 1.12 is in place but output is plain-text `StreamLogHandler`.
Good next steps:

- JSON log handler for production runs (structured logging is invaluable
  for large gallery builds on a server).
- Add `Logger.Metadata` at key spots: photo path on every photo-level log
  line, album path on album-level, etc.
- File-output log handler (plumbed but not implemented; see the TODO in
  `Context.init`).

---

## 7. Nix + Swift packaging

`flake.nix` intentionally does not provide a Swift toolchain because
nixpkgs' Swift derivations trail Swift.org releases and interact awkwardly
with the C-library stdenv. Revisit if nixpkgs' `swift` package becomes
current and reliably builds on Linux — at that point `nix build` could
return (previously dropped with `swiftpm2nix`).

---

## 12. Static binary distribution

Done: `make build-static` cross-builds fully static musl binaries for amd64
and arm64 and CI publishes them. See `build/musl-sysroot/README.md`. What is
left:

- **Size.** ~72 MB, of which 32.4 MB is `icu_packaged_data.cpp.o` inside the
  SDK's `lib_FoundationICU.a` — about 45% of the binary, and the single
  biggest lever. Dropping it means not importing
  `FoundationInternationalization`, which is a source change.
- **HEIC/AVIF** is deliberately out of the static build (libheif plus a C++
  HEVC/AV1 decoder). Revisit if someone actually needs it; the dynamic build
  still has whatever the distro's libvips supports.
- **Reproducibility.** Two builds of the same source differ in 3,871 bytes —
  20 in `.note.gnu.build-id`, 3,851 in `.swift_modhash`, and nothing in
  `.text`/`.rodata`/`.data`. Only worth chasing if release attestations
  become interesting.

Recorded so nobody rediscovers it: `swift build --static-swift-stdlib` is a
different and much weaker thing — it links the *Swift* runtime statically and
leaves 11 `DT_NEEDED` entries and a 107-library shared-object closure (libvips,
glib, libstdc++, glibc itself). Munin used to have a `build-static-stdlib`
target for it; it was dropped because it serves no purpose the musl build does
not serve better.

---

## 13. Output path collisions — done, the build now refuses them

Munin derives output names from source *names*, and three of those
derivations lost information: photo metadata is `<stem>.json` with the
extension dropped, an album folder is `urlifyName(name)` with spaces turned
into underscores, and a keyword page is `keywords/<urlifyName(name)>.json`.
So `sample.jpg` + `sample.jpeg` resolved to one `sample.json`, sibling
directories `My Album` + `My_Album` to one folder, and the IPTC keywords
`Tel Aviv District` + `Tel_Aviv_District` to one page. Each wrote to the same
path, the winner was whichever write landed last, and one of the user's
photos was silently missing either way — from the gallery, or from the
keyword page its own JSON links to. The album variant was worse: each album's
`clean` deleted the other's outputs, so both lost everything.

The earlier note here claimed this was unreachable on the default
`fileExtensions`. That was wrong twice over — the default list is
`["jpg", "jpeg", "JPG", "JPEG"]`, four spellings of one stem, and the album
variant involves no photo extension at all.

`Gallery.load` now calls `findOutputPathCollisions` before reading or writing
anything and throws `MuninError.outputPathCollision` listing every contested
output path with all of its sources. Erroring was chosen over inventing a
disambiguated name (`sample_jpg.json`): output URLs are Munin's public
artifact, and a collision-only renaming rule would silently move an existing
photo's URL the moment a colliding file was added or removed. A collision is
always an accident, and the person who hit it can fix it with one `mv`.

The keyword namespace needs a second pass — those names live in each photo's
IPTC, so they do not exist until the read is done. `findKeywordOutputPathCollisions`
runs at the end of `Gallery.load` and throws `MuninError.keywordPathCollision`.
That is later, but not weaker in the way that matters: nothing has been
written yet, so a rejected build still leaves the previous gallery untouched.
It covers the people namespace in the same pass — keywords and people share
`content/keywords/`, and two names that urlify alike can sit one in each
bucket (a name is never in both: `applyConfigDerivedFields` re-splits the
union against `allPeople`, so the bucket is a function of the name).

One interaction still uncovered: a gallery whose name urlifies to `keywords`
puts its album tree in the directory the keyword pages live in, so a
root-level photo `x.jpg` and a keyword `x` would contend. Same family as the
gallery-name breakage in item 14 below and it wants the same fix.

`scripts/testdata/formats` keeps distinct basenames because the fixture is
about decoding PNG/WebP/TIFF, not about collisions.

Two related paths were repaired in the same change:

- Sub-albums were handed the parent's *raw* name as their output root while
  the parent's own folder was urlified, so everything below an album whose
  name contained a space was written to a parallel directory the parent never
  claimed — and then deleted by the parent's `clean` as unreferenced.
- `Photo.<`, `Album.<`, `Keyword.<`, `KeywordPointer.<` and `Location.<` were
  not total orders. Every JSON array Munin writes is
  `Array(someSet).sorted()`, and `sorted()` is stable, so a tie kept `Set`
  iteration order — which comes from the per-process randomised hash seed.
  Each now falls back to comparing the output url, byte-wise when Swift's
  canonical `String` comparison calls two spellings equal (NFC vs NFD, which
  is what a macOS-synced tree hands a Linux host). See
  `OrderingTotalityTests`, which asserts the invariant over all five rather
  than over the four whose ties are reachable from a current call site:
  `Keyword.<`'s cannot be, because `buildKeywordsFromAlbum` keys its
  accumulator by name and hands the sort canonically-distinct names.

---

## 14. Remaining nondeterminism, none of it currently reachable in `example/`

Found while fixing item 13, deliberately left alone. Each is real; none is
worth the behaviour change it would cost right now.

- **Keyword aggregation picks a filename by `Set` order.**
  `buildKeywordsFromAlbum` keys a dictionary by keyword *name*, and Swift
  `String` keys are canonical, so `Håkon` spelled NFC and NFD land on one
  entry — but the `Keyword.url` that entry keeps is whichever photo
  `flattenPhotos()` yielded first, and `flattenPhotos()` returns a
  `Set<Photo>`. So the keyword file's own name flips between runs, and the
  photo whose spelling lost links to a page that does not exist. This is the
  only known nondeterminism still reachable in gallery output.

  Note what does *not* fix it: the `Keyword.<` tie-break added in item 13.
  The two spellings never reach that comparator as two elements — the
  dictionary merged them into one entry long before the sort, and it is the
  merge, not an ordering tie, that drops a url. Fixing it properly means
  deciding whether two spellings are one keyword or two, which is a
  modelling question. A cheap deterministic patch exists (key the
  accumulator by url bytes, or pick the surviving url by
  `canonicalThenBytewiseLess` instead of by arrival) — it would still merge
  the photos under one page, but the page's name would stop flipping.
- **`Parent.<` sorts the ancestor chain by name**, destroying hierarchy
  order. Deterministic today only because the input array is, and the sort is
  stable. Semantically wrong; one refactor away from mattering.
- **`Photo+Read`'s `fileModificationDate(...) ?? Date()`** puts wall-clock
  time into `modifiedDate` if `stat` fails mid-build, which then propagates
  into the incremental cache.
- **`BuildReport.failures`** is appended in task-completion order, so the
  CLI's failure list varies between runs. Stdout only; no gallery output.
- **A gallery `name` containing a space does not build at all.** The root
  album folder is `urlifyName(name)` but `Statistics.write`,
  `Locations.write` and `Gallery.load`'s output-index lookup all use the raw
  `name`, so with `"name": "My Gallery"` the album tree lands in
  `content/My_Gallery/` and then `stats.json` fails with
  `open (temp) failed for 'content/My Gallery/stats.json.tmp…': No such file
  or directory`. Deterministic and loud, unlike the sub-album variant fixed
  in item 13, and the same one-word fix in three more places — but it moves
  output paths, so it is not a determinism change. The collision check
  claims `stats.json`/`locations.json` at the *urlified* root, i.e. where
  they would be once this is fixed.
- **`FilesystemSnapshot` (test support) keys entries by Swift `String`**, so
  two output paths that are byte-distinct but canonically equal collapse into
  one entry and the byte-for-byte stability gates cannot see one of them.
  `OutputPathCollisionTests` and `StabilityTests` assert against raw UTF-8
  where it matters; the shared helper is still blind.
