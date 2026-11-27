# nix/ — the builds

One Swift, nixpkgs', pinned by `flake.lock`, for every build and every system.

```sh
nix build                          # x86_64-linux: static amd64; elsewhere: dynamic
nix build .#munin-static-arm64
nix build .#munin-dynamic
nix flake check                    # static x2, smoke x2, unit tests, lint
nix develop                        # swift, swiftpm, swift-format, swiftlint, C libs
```

The static build needs no dynamic loader and no shared libraries: the kernel
runs the file directly, and it reads nothing from the filesystem to start. One
file runs on any Linux of the right architecture. Both architectures
cross-compile from `x86_64-linux`.

No `--impure`, no `NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM`. If you find yourself
reaching for either, something regressed.

## Using it from another flake

```nix
inputs.munin.url = "github:kradalby/munin";

# NixOS
nixpkgs.overlays = [ inputs.munin.overlays.default ];
environment.systemPackages = [ pkgs.munin-gallery ];

# or without the overlay
environment.systemPackages = [ inputs.munin.packages.${system}.default ];
```

`munin-gallery`, because nixpkgs' `munin` is the resource monitoring tool and
shadowing it would replace a monitoring host's daemon. The binary is still
`munin`. The overlay is the static build, x86_64-linux only, and uses this
flake's pinned nixpkgs: thumbnails are a function of the libvips linked, and
`example/content` is the baseline for that version.

No NixOS or nix-darwin module — munin is a batch CLI, so one would amount to
`environment.systemPackages`.

## What each file is

| File | Role |
| --- | --- |
| `munin.nix` | the dynamic build, and `swift test` as `passthru.tests.unit` |
| `munin-static.nix` | the static Swift build and the link |
| `sdk.nix` | the Static Linux SDK artifactbundle, fixed up for nixpkgs' swift |
| `cross-pkgs.nix` | the static-musl package set, with its overrides |
| `vips.nix` | a trimmed static-musl libvips out of nixpkgs |
| `gallery.nix` | a gallery built by the static binary, as a derivation |
| `testdata/` | PNG/WebP/TIFF fixtures for the smoke checks |

SwiftPM dependencies come from nixpkgs' `fetchSwiftPMDeps` (one hash in
`flake.nix`, read from `Package.resolved`) and its unpack hook.

## The Static SDK on nixpkgs' swift

Two fixes, both in `sdk.nix`:

1. **An unwrapped clang in the SDK's `toolset.json` rootPath.** nixpkgs' clang
   is a cc-wrapper that adds host glibc `crt1.o` and GNU `ld` to every link.
   The script adds the flags swift.org's `<triple>-clang.cfg` would.
2. **An empty `sys/cdefs.h` in each musl sysroot.** nixpkgs' ClangImporter
   adds host glibc headers whenever arch and OS match the host, without
   checking the libc. x86_64-musl matches; aarch64-musl does not. musl has no
   `sys/cdefs.h`, so libdispatch's `__has_include` found glibc's.

Fix 2 can go once nixpkgs' `isWrappedCompilerTarget` compares the environment
too.

## Bumping Swift

Bump `flake.lock`. If `swift.version` moved, update the SDK hash in
`sdk.nix`. swift.org publishes no `.sha256` sidecar; the reviewable source is
their data file:

```sh
curl -fsSL https://raw.githubusercontent.com/swiftlang/swift-org-website/main/_data/builds/swift_releases.yml \
  | grep -A2 'platform: static-sdk'
```

`sha256sum` on a tarball you just downloaded is not a check — it only proves
the bytes arrived intact. Convert with `nix hash convert --to sri`.

## Bumping the SwiftPM dependencies

Change `Package.resolved`, build, and take nix's fixed-output mismatch into
the `fetchSwiftPMDeps` hash in `flake.nix`.

## What drifts

`vips.nix` shadows a nixpkgs package — its input lists and its meson flags —
so a nixpkgs bump that reshapes vips' options breaks it with no warning.

`checks.smoke-*` is the early signal: a bump that moves an encoder shows up as
a byte diff against `example/content` **on the commit that bumped
`flake.lock`**. When the new output is correct:

```sh
nix run .#regen-example-content
```

The gallery derivation pins source mtimes itself, so the result is the same on
every machine.

## Things that look removable and are not

- **`remove-references-to`.** vips and glib compile their module and locale
  prefixes in as dead string literals. Nix sees store paths and retains the
  entire C closure, several times the size of the binary itself. The assertion
  after it stops that coming back silently.
- **`.all` rather than `${p}`** when collecting those paths. glib's default
  output is `bin`; the archives and prefixes live in `out`.
- **The libjpeg SIMD assertion.** CMake falls back to a scalar codec when it
  finds no assembler, costing several times the JPEG encode speed — munin's hot
  path. SIMD and scalar are bit-identical, so nothing else can notice.
- **`gifSupport = false`.** giflib builds a `.so` unconditionally and fails to
  link under `pkgsStatic`; vips reads GIF through cgif.
- **The `zlib.pc` stub.** nixpkgs' static musl zlib ships no `.pc`, and
  SwiftPM drops *every* cflag when one `Requires` entry is missing — surfacing
  as `'glib.h' file not found`.
- **`pkg-config --static` in `buildPhase`.** SwiftPM reads `Libs` but not
  `Requires.private`, so the link comes up short by every transitive archive.
- **The format fixtures in the smoke checks.** `example/` is all JPEG, so a
  JPEG-only libvips passes the byte diff.

## No unit tests against musl

The Static SDK ships no XCTest or swift-testing, so `swift test --swift-sdk`
is impossible. `checks.<system>.unit` runs the suite against the dynamic
build; the static artifacts get `checks.smoke-*`.
