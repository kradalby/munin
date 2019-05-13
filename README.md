![Munin](assets/munin_black.svg)

[Munin](https://en.wikipedia.org/wiki/Huginn_and_Muninn) is one of a pair of ravens that fly all over the world, Midgard, and bring information to the god Odin.

Munin is a static "api" image gallery generator. Munin will take a folder structure and turn it into a linked json api with responsive images. The idea is that the input folder structure will act as the "state" or "source of truth" and will be compared to the currently generated gallery and a diff will be generated. The first run will create a new gallery and the consecutive runs will only encode thumbnails and json files for new images/folders.

Munin does not come with a frontend, and encourages you to "bring your own" or pair it with [Hugin](https://github.com/kradalby/hugin).

Munin uses ImageIO for reading image metadata and encoding of images which currently makes it macOS only. The grand central dispatch infrastructure is used to parallellise a lot of the tasks to speed up encoding on multi processor machines.


## Features

- Organise your album as folders
- Generate albums fast!
    - Generate only changed albums/images
    - Encode with all available cores
    - Reuse original images by symlinking ([example]())
    - Generate multiple sizes for responsive usage
- Structure EXIF and other metadata as JSON ([example]())
- Structure image by keywords ([example]())
- Structure image by people ([example]())
- Extract location data from images ([example]())
- Statistics ([example]())

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
Munin is configured with a simple json file:

```json
{
    "name": "root",
    "resolutions": [1600, 1200, 992, 768, 576, 340, 220, 180],
    "jpegCompression": 0.75,
    "inputPath": "album",
    "outputPath": "content",
    "fileExtentions": ["jpg", "jpeg", "JPG", "JPEG"],
    "logLevel": 1,
    "diff": true,
    "people": [
        "Kristoffer Andreas Dalby"
    ]
}
```


## Install

### Installing with [mint](https://github.com/yonaskolb/Mint)

    mint run kradalby/munin

### Building yourself
This installation will put the binary to `~/bin` which needs to be in your path. If you would like to install it elsewhere, take a look at the `Makefile`

Requirements:
- Swift 5
- Xcode 10.2
- git

Clone:

    git clone https://github.com/kradalby/munin

Build and install:

    cd munin
    make install


## Development
Please see the requirements in [Building yourself](#Building yourself).

Generate a Xcode project:

    make dev
    open Munin.xcodeproj

or bring your favourite editor.

### Code style
When developing on the project, be sure to follow the standard setup of [Swiftlint](https://github.com/realm/SwiftLint) and [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)

All linters can be run with:

    make lint

All linters are ran on the CI whenever a change is comitted.
