# nix/ — the static Linux build

Builds a `munin` that needs no dynamic loader and no shared libraries: the
kernel runs the file directly, and it reads nothing from the filesystem to
start. One file runs on any Linux of the right architecture — a bare container,
a distro with no libvips, anything.

Both architectures cross-compile from `x86_64-linux`; there is no arm64 builder
in this path.

```sh
nix build .#munin-static-amd64      # = .#default
nix build .#munin-static-arm64
nix flake check                     # both, plus smoke, formats and lint
```

No `--impure`, no `NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM`. If you find yourself
reaching for either, something regressed.

## Using it from another flake

```nix
inputs.munin.url = "github:kradalby/munin";

# NixOS
nixpkgs.overlays = [ inputs.munin.overlays.default ];
environment.systemPackages = [ pkgs.munin-gallery ];

# or without the overlay
environment.systemPackages = [ inputs.munin.packages.x86_64-linux.munin ];
```

`munin-gallery`, because nixpkgs' `munin` is the resource monitoring tool and
shadowing it would replace a monitoring host's daemon. The binary is still
`munin`.

The overlay ignores `final`/`prev` and uses this flake's pinned nixpkgs:
thumbnails are a function of the libvips linked, and `example/content` is the
baseline for that version.

**x86_64-linux only.** On aarch64-linux the artifact runs but cross-compiles
from x86_64, so an aarch64 host cannot realise it locally — substitute from a
cache or use a remote builder. On Darwin there is no package: the toolchain
lives in Xcode, outside the store. `nix develop` works there; `nix build` does
not.

No NixOS or nix-darwin module — munin is a batch CLI, so one would amount to
`environment.systemPackages`.

## What each file is

| File | Role |
| --- | --- |
| `toolchain.nix` | the swift.org 6.3.1 tarball, patchelfed onto nixpkgs |
| `sdk.nix` | the Static Linux SDK artifactbundle, untarred |
| `cross-pkgs.nix` | the static-musl package set, with its overrides |
| `vips.nix` | a trimmed static-musl libvips out of nixpkgs |
| `deps.nix` | SwiftPM's 10 git checkouts as one fixed-output derivation |
| `munin-static.nix` | the Swift build and the link |

Each file carries its reasoning at the point of use; this covers only what
does not belong in one.

## Why not nixpkgs' Swift

It is years behind, and SwiftPM rejects this package's manifest before parsing
it — the tools version in `Package.swift` is newer than nixpkgs' compiler
understands. `toolchain.nix` uses the same Ubuntu tarball CI does.

Three things make that tarball work under nix:

1. **`autoPatchelfHook`, with `libxml2_13`** — `swift-build` links an older
   libxml2 soname than nixpkgs ships. `libedit` and python are ignored: lldb
   only.
2. **`bin/clang.cfg`** — nix has no `/usr/include`, no `crt1.o` on a default
   path, and a stub `ld-linux`. clang loads exactly one config file and the
   musl triples already have theirs, so this covers the host and is shadowed
   on a cross link. It is what lets SwiftPM compile, link **and run**
   `Package.swift`.
3. **`SDKROOT`** — `swift-frontend` embeds clang and never reads the driver
   config. Without it: "missing required module 'SwiftGlibc'", then a missing
   `swiftrt.o`.

## Bumping Swift

`toolchain.nix` and `sdk.nix` each carry a `version` and a hash, and
`.swift-version` carries the pin the Docker image reads. All three move
together.

The SDK checksum is awkward: swift.org publishes no `.sha256` sidecar. The
reviewable source is their own data file:

```sh
curl -fsSL https://raw.githubusercontent.com/swiftlang/swift-org-website/main/_data/builds/swift_releases.yml \
  | grep -A2 'platform: static-sdk'
```

Entries are in release order. `sha256sum` on a tarball you just downloaded is
not a check — it only proves the bytes arrived intact. Convert with `nix hash
convert --to sri`.

The toolchain tarball has no published hash; take nix's mismatch and
sanity-check the `swift --version` it produces.

## Bumping the SwiftPM dependencies

Change `Package.resolved`, build, and take nix's fixed-output mismatch into
`munin-static.nix`'s `deps` call. `deps.nix` reads `Package.resolved`, so
there is no second revision list.

## What drifts

`vips.nix` shadows a nixpkgs package — its input lists and its meson flags —
so a nixpkgs bump that reshapes vips' options breaks it with no warning.

`checks.smoke-amd64` is the early signal: a bump that moves an encoder shows
up as a byte diff **on the commit that bumped `flake.lock`**. When the new
output is correct, regenerate:

```sh
nix build .#munin-static-amd64
scripts/regen-example-content.sh ./result/bin/munin
```

Use the script, not the binary by hand: it pins the source mtimes first, and a
baseline made without that only passes on the machine that made it.

## Things that look removable and are not

- **`remove-references-to`.** vips and glib compile their module and locale
  prefixes in as dead string literals. Nix sees store paths and retains the
  entire C closure, several times the size of the binary itself. The assertion
  after it stops that coming back silently.
- **`.all` rather than `${p}`** when collecting those paths. glib's default
  output is `bin`; the archives and prefixes live in `out`.
- **The libjpeg SIMD assertion.** CMake falls back to a scalar codec when it
  finds no assembler, costing several times the JPEG encode speed — munin's hot
  path. SIMD and scalar are bit-identical (`JSIMD_FORCENONE=1` changes not one
  generated file), so nothing else can notice.
- **`gifSupport = false`.** giflib builds a `.so` unconditionally and fails to
  link under `pkgsStatic`; vips reads GIF through cgif.
- **The `zlib.pc` stub.** nixpkgs' static musl zlib ships no `.pc`, and
  SwiftPM drops *every* cflag when one `Requires` entry is missing — surfacing
  as `'glib.h' file not found`.
- **`pkg-config --static` in `buildPhase`.** SwiftPM reads `Libs` but not
  `Requires.private`, so the link comes up short by every transitive archive.

## No unit tests here

The Static SDK ships no XCTest or swift-testing, so `swift test --swift-sdk`
is impossible. The suite runs against the dynamic builds in
`.github/workflows/swift-ci.yml`; the static artifacts get `checks.smoke-*`.
