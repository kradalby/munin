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

The remaining functional gap, regardless of replacement: SwiftExif
0.1.0 still can't distinguish "no EXIF present" from "EXIF present
but corrupt" — both surface as an empty `ExifResult`. Distinguishing
the two would let `Photo+Read` log "image X had unreadable EXIF"
instead of silently degrading.

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

## 11. `VIPSImage.write` API migration

`swift-vips` main has evolved; the project is SHA-pinned. When a tag is
cut upstream:
- Move the dependency back to a `from:` version pin.
- Re-examine `Sources/MuninKit/IO/Imaging/VIPS.swift` for the
  `Optional<VipsInteresting>.none` workaround — it's a pre-existing
  type-inference nit in swift-vips' API.

---

## 12. Static binary distribution

`make build-static` uses `--static-swift-stdlib` which produces a ~73 MB
binary with no Swift-runtime `.so` dependencies but still depends on the
system's C libraries (libvips, libexif, etc.). The truly-static
(musl-based) build path was investigated on the old `swift-61-2` branch
and abandoned — see that branch's history for the detailed notes. Revisit
if the `sharp-libvips` approach becomes more broadly usable.

