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

Every release publishes a fully static Linux binary — no `PT_INTERP`, no
`DT_NEEDED`, no libvips or Swift runtime to install. It runs on any Linux of
the right architecture, including `FROM scratch` containers. Both properties
are gates, not observations: the build fails if the binary has either, and
nothing is published unless the build passes.

Every push to `master` republishes a rolling prerelease under the tag
`latest`:

```bash
curl -L -o munin https://github.com/kradalby/munin/releases/download/latest/munin-linux-amd64
# or munin-linux-arm64
chmod +x munin
./munin --help
```

Tagged releases (`v*`) are permanent, and the newest one is served from a
different URL shape — note the swapped path segments:

```bash
curl -L -o munin https://github.com/kradalby/munin/releases/latest/download/munin-linux-amd64
```

`/releases/latest/download/…` resolves GitHub's "latest release" pointer,
which excludes prereleases: it never serves the rolling build, and it 404s
until the first `v*` tag exists. `/releases/download/latest/…` is keyed on
the tag name `latest` and always serves the rolling build. Both use the same
asset names, and `SHA256SUMS` is published alongside the binaries in both.

The binaries are ~72 MB (~29 MB gzipped). Roughly half of that is ICU data
compiled into Foundation, which cannot be dropped without dropping
`FoundationInternationalization`.

Two things differ from a distro-libvips build, both deliberate:

- **Image formats: JPEG, PNG, WebP and TIFF.** All four are exercised end to
  end on both architectures before anything is published — each decoded from a
  file written by an unrelated encoder, then re-encoded by Munin
  (`make smoke-static-amd64`, which the release build runs for both arches).
  **HEIC/AVIF is not supported** (it would drag libheif and a C++ HEVC/AV1
  decoder into the static closure), and neither are libtiff's exotic codecs
  (zstd, lzma, jbig, lerc) or paletted PNG output. If your `fileExtensions`
  includes `heic`, use a build linked against your distro's libvips instead.
- **No Swift backtracing.** The Static Linux SDK compiles in
  `SWIFT_BACKTRACE=enable=no` and there is no `swift-backtrace` helper to
  find, so a crash gives a bare `SIGILL` with no symbolicated trace. Setting
  `SWIFT_BACKTRACE=enable=yes` only prints a line saying the helper is
  missing. Reproduce crashes against a dynamically linked build.

### Build from source

#### Requirements

- **Swift 6.3.1** (matches CI) — install via
  [swiftly](https://www.swift.org/install/) or the
  [Swift.org tarball](https://download.swift.org/). `nixpkgs`' Swift lags
  upstream and is not used by this project; see `flake.nix` for the dev
  shell that provides just the C library deps.
- **Ubuntu 24.04** (primary CI target) or macOS 14+
- **System C libraries**:

  Ubuntu / Debian:

  ```bash
  sudo apt install libvips-dev libexif-dev libiptcdata0-dev pkg-config
  ```

  macOS (Homebrew):

  ```bash
  brew install vips libexif libiptcdata pkg-config
  ```

  Nix (via the bundled flake):

  ```bash
  nix develop
  ```

  The devShell provides every C dependency. It **does not** provide Swift,
  `swift-format` or `sourcekit-lsp` — nixpkgs' versions of those are built
  against a different Swift than the toolchain you compile with. Install them
  alongside the toolchain via swiftly or the Swift.org tarball.

#### Build and install

```bash
git clone https://github.com/kradalby/munin
cd munin
make install   # builds release, copies binary to ~/bin/munin
```

#### Building the static Linux binaries yourself

Needs Docker and about 15 minutes the first time; everything is cross-compiled
from one x86_64 container, so no arm64 machine is involved.

```bash
make build-musl-sysroot   # cross-build + verify the C closure (vips, glib, jpeg, …) for both arches
make build-static         # -> .build/{x86_64,aarch64}-swift-linux-musl/release/munin
make smoke-static-amd64   # end-to-end acceptance: portability, full example/ build, formats
```

See `build/musl-sysroot/README.md` for what the sysroot contains and why. Never
run these inside `nix develop` — SwiftPM's `.pc` parser reads host pkg-config
directories during a cross build and will link the wrong libraries.

The smoke test diffs the generated gallery byte-for-byte against the committed
`example/content`, so any change to Munin's JSON output makes it fail until
that baseline is refreshed:

```bash
make build-release                                       # native build, in this order:
scripts/regen-example-content.sh .build/release/munin    # `.build/release` follows the
                                                         # last triple built
```

Any Munin build produces the same tree, so it does not have to be the static
one — but it does have to be a *native* build, and `.build/release` is a
symlink SwiftPM repoints at whatever triple it last built, so run the build
immediately before the script.

Use the script rather than running the binary over `example/` by hand. Munin
copies each source image's mtime into its JSON and git does not preserve
mtimes, so the script pins them first — a baseline regenerated without that
step passes on the machine that made it and fails on every fresh checkout.
`scripts/normalise-mtimes.sh` explains the whole story.

## Development

Assuming Swift and the system libraries from the Requirements section above
are in place:

```bash
make build         # debug build
make test          # run test suite (requires libvips on your system)
make run           # build + run the binary
make lint          # swiftlint
make fmt           # swiftlint --fix + swift-format
```

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
