![Munin](assets/munin_black.svg)

[Munin](https://en.wikipedia.org/wiki/Huginn_and_Muninn) is one of a pair of ravens that fly all over the world, Midgard, and bring information to the god Odin.

Munin is a static "api" image gallery generator. Munin will take a folder structure and turn it into a linked json api with responsive images. The idea is that the input folder structure will act as the "state" or "source of truth" and will be compared to the currently generated gallery and a diff will be generated. The first run will create a new gallery and the consecutive runs will only encode thumbnails and json files for new images/folders.

Munin does not come with a frontend, and encourages you to "build your own" or pair it with [Hugin](https://github.com/kradalby/hugin).

Munin uses [libvips](https://www.libvips.org/) (via [swift-vips](https://github.com/t089/swift-vips)), [libexif](https://libexif.github.io) and [libiptcdata](http://libiptcdata.sourceforge.net) to read, resize, write images and their metadata. Munin runs on both macOS and Linux.

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

### Requirements

- **Swift 6.3.1** (matches CI) — install via
  [swiftly](https://www.swift.org/install/) or the
  [Swift.org tarball](https://download.swift.org/). `nixpkgs`' Swift lags
  upstream and is not used by this project; see `flake.nix` for the dev
  shell that provides just the C library deps.
- **Ubuntu 24.04** (primary CI target) or macOS 14+
- **System C libraries**:

  Ubuntu / Debian:

  ```bash
  sudo apt install libvips-dev libexif-dev libiptcdata0-dev libgd-dev pkg-config
  ```

  macOS (Homebrew):

  ```bash
  brew install vips libexif libiptcdata pkg-config
  ```

  Nix (via the bundled flake):

  ```bash
  nix develop
  ```

  The devShell provides every C dependency and the developer tools
  (`swift-format`, `sourcekit-lsp`). It **does not** provide Swift — install
  that separately via swiftly or the Swift.org tarball.

### Build and install

```bash
git clone https://github.com/kradalby/munin
cd munin
make install   # builds release, copies binary to ~/bin/munin
```

Or, for a static-stdlib build (~73MB, no Swift runtime dependencies):

```bash
make build-static
```

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
