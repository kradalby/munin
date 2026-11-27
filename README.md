![Munin](assets/munin_black.svg)

[Munin](https://en.wikipedia.org/wiki/Huginn_and_Muninn) is one of a pair of ravens that fly all over the world, Midgard, and bring information to the god Odin.

Munin is a static "api" image gallery generator. Munin will take a folder structure and turn it into a linked json api with responsive images. The idea is that the input folder structure will act as the "state" or "source of truth" and will be compared to the currently generated gallery and a diff will be generated. The first run will create a new gallery and the consecutive runs will only encode thumbnails and json files for new images/folders.

Munin does not come with a frontend, and encourages you to "build your own" or pair it with [Hugin](https://github.com/kradalby/hugin).

Munin uses [libvips](https://www.libvips.org/) (bound directly: Munin performs exactly three libvips operations — open, thumbnail, save — so the whole binding is `Sources/Cvips` and `Sources/MuninVipsShim`, ~45 lines of C, plus `Sources/MuninVips`, one Swift file that owns the GObject refcounts), [libexif](https://libexif.github.io) and [libiptcdata](http://libiptcdata.sourceforge.net) to read, resize, write images and their metadata. Munin runs on both macOS and Linux.

## Features

- Organise your album as folders
- Generate albums fast!
  - Generate only changed albums/images
  - Encode with all available cores via Swift structured concurrency (`TaskGroup` + `AsyncSemaphore`)
  - Reuse original images by symlinking
  - Generate multiple sizes for responsive usage
- Structure EXIF and other metadata as JSON
- Structure image by keywords
- Structure image by people
- Extract location data from images
- Statistics

## Usage

Help:

    $ munin --help

Usage:

    $ munin

    Options:
        --config [default: munin.json] - JSON based configuration file for munin
        --dry [default: false] - Dry-run, do not write gallery
        --json [default: false] - Write only JSON files, no images, useful for updating data with new munin features

### Configuration

Munin is configured with a simple JSON file:

```json
{
  "name": "root",
  "resolutions": [1600, 1200, 992, 768, 576, 340, 220, 180],
  "jpegCompression": 0.75,
  "sourceFolder": "album",
  "targetFolder": "content",
  "fileExtensions": ["jpg", "jpeg", "JPG", "JPEG"],
  "logLevel": "info",
  "diff": true,
  "people": ["Kristoffer Andreas Dalby"]
}
```

Every field has a sensible default (see `MuninConfiguration` in
`Sources/MuninKit/Configuration.swift`); the only fields you likely need to
set are `sourceFolder` and `targetFolder`.

Configuration values can also be overridden with `MUNIN_*` environment
variables (e.g. `MUNIN_SOURCE_FOLDER`, `MUNIN_CONCURRENCY`) or with
`--key value` command-line arguments.

## Install

### Linux: download a binary

Every release publishes one file per architecture. It needs no dynamic loader
and no shared libraries — no libvips, no Swift runtime, nothing installed at
all — so it runs on any Linux of the right architecture, including `FROM
scratch` containers. That is a gate, not an observation: the build fails if the
binary depends on anything, and nothing is published unless the build passes.

Releases are cut from `v*` tags, and the newest is always at:

```bash
curl -L -o munin https://github.com/kradalby/munin/releases/latest/download/munin-linux-amd64
# or munin-linux-arm64
chmod +x munin
./munin --help
```

`SHA256SUMS` is published alongside. That URL 404s until the first `v*` tag
exists.

To try an unreleased change, take the binary from its CI run instead: every
push and pull request attaches `munin-linux-amd64` and `munin-linux-arm64` to
the **Static Linux** workflow run, downloadable from the run page. They are
built exactly the same way as a release.

The binaries are large. Most of that is ICU data compiled into Foundation,
which cannot be dropped without dropping `FoundationInternationalization`.

Two things differ from a distro-libvips build, both deliberate:

- **Image formats: JPEG, PNG, WebP and TIFF.** All four are exercised end to
  end on both architectures before anything is published — each decoded from a
  file written by an unrelated encoder, then re-encoded by Munin
  (`checks.smoke-*`, which the release build runs for both arches).
  **HEIC/AVIF is not supported** (it would drag libheif and a C++ HEVC/AV1
  decoder into the static closure), and neither are libtiff's exotic codecs
  (zstd, lzma, jbig, lerc) or paletted PNG output. If your `fileExtensions`
  includes `heic`, use a build linked against your distro's libvips instead.
- **No Swift backtracing.** The Static SDK compiles it out and ships no
  backtrace helper, so a crash gives a bare signal with no symbol names.
  Setting `SWIFT_BACKTRACE=enable=yes` only prints a line saying the helper is
  missing. Reproduce crashes against a dynamically linked build.

### Build from source

With nix (Linux or macOS) — the flake pins Swift and every C library:

```bash
git clone https://github.com/kradalby/munin
cd munin
nix build            # x86_64-linux: the static binary; elsewhere: dynamic
```

Without nix: Swift 6.4 from [swift.org](https://www.swift.org/install/), plus

```bash
sudo apt install libvips-dev libexif-dev libiptcdata0-dev pkg-config   # Ubuntu / Debian
brew install vips libexif libiptcdata pkg-config                       # macOS
make install         # release build, copied to ~/bin/munin
```

#### The static Linux binaries

Both architectures cross-compile from x86_64, so no arm64 machine is involved.

```bash
make static          # -> nix build .#munin-static-{amd64,arm64}
nix flake check      # portability, full example/ build, PNG/WebP/TIFF
```

The smoke checks diff the generated gallery byte for byte against the
committed `example/content`, so a change to Munin's output fails them until
the baseline is refreshed:

```bash
make regen-example   # -> nix run .#regen-example-content
```

`nix/README.md` covers what the closure contains, how to bump Swift, and what
drifts.

## Development

```bash
nix develop          # swift, swiftpm, swift-format, swiftlint, C libraries
make build           # debug build
make test            # run test suite
make run             # build + run the binary
make lint            # swiftlint
make fmt             # swiftlint --fix + swift-format
make check           # everything CI runs
```

Binaries built in the devShell run there: it uses the same stdenv as the
package, so they carry an rpath to their C libraries.

### Code style

Follow [SwiftLint](https://github.com/realm/SwiftLint) and
[swift-format](https://github.com/swiftlang/swift-format) defaults. Both
tools are available in the nix devShell; `make fmt` runs both.

### Architecture notes

- `Sources/MuninKit` — library: gallery model, read/write pipelines, config.
  The code lives across small, focused files split by concern
  (`Album+Read.swift`, `Album+Write.swift`, `Photo+EXIF` inlined in
  `Photo+Read.swift`, etc.).
- `Sources/Munin` — `AsyncParsableCommand` CLI entrypoint.
- `Tests/MuninKitTests` — XCTest-based; each test uses a unique temp
  directory and shares a single VIPS initialisation via
  `VIPSBootstrap.startForTesting()`.

Concurrency is based on `async`/`await` + `TaskGroup`; there are no
`DispatchQueue`s or `DispatchGroup`s in the source. `AsyncSemaphore`
bounds concurrent VIPS/EXIF reads and image writes per-gallery based on
the `concurrency` config value.
