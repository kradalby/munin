# build/musl-sysroot — Munin's static C closure

Cross-builds every C library Munin links against into **static musl archives**
for `x86_64-swift-linux-musl` and `aarch64-swift-linux-musl`, so
`swift build --swift-sdk <triple>` can produce a Linux binary with no
`PT_INTERP` and no `DT_NEEDED` entries.

One x86_64 container produces both architectures. There is no Alpine base, no
arm64 runner, and no qemu in the build path — `qemu-user-static` is installed
only so meson can run the few compile-and-run probes an aarch64 build needs.

## Use

`make build-musl-sysroot` from the repo root does all of the below — image,
both arches, and `verify.sh` after each. ~15 min cold, seconds when stamped.
By hand, e.g. to redo one stage:

```sh
docker build -t munin-musl build/musl-sysroot

MOUNTS="-v $PWD/build/musl-sysroot:/recipe:ro -v $PWD/.build/musl-sysroot:/work"

docker run --rm $MOUNTS munin-musl bash /recipe/build.sh x86_64
docker run --rm $MOUNTS munin-musl bash /recipe/verify.sh x86_64
docker run --rm $MOUNTS munin-musl bash /recipe/build.sh aarch64
docker run --rm $MOUNTS munin-musl bash /recipe/verify.sh aarch64

# one stage only, ignoring its stamp
docker run --rm -e FORCE=1 $MOUNTS munin-musl bash /recipe/build.sh x86_64 tiff
```

The recipe and the output tree are separate mounts on purpose: the recipe is
checked in, the output tree is multi-gigabyte scratch. `$WORK` (default
`/work`) holds `dl/` (tarball cache), `src/`, `build/`, `logs/<arch>/`,
`cross/` (generated meson + cmake cross files) and `out/<arch>/` (the finished
prefix). Stages are stamped under `out/<arch>/.stamps`; delete a stamp or pass
`FORCE=1` to rebuild one.

Afterwards, `out/<arch>/lib/pkgconfig` is what `PKG_CONFIG_PATH` must point at
for the Swift cross build.

Every `.pc` file in the prefix carries **absolute container paths**
(`prefix=/work/out/<arch>`), so the Swift build must mount the same scratch
tree at the same mountpoint — `/work` by default. Moving the prefix without
rewriting the `.pc` prefixes will not work.

## What gets built

| Stage | Why |
| --- | --- |
| `khdrs` | Alpine's `linux/*.h` + `asm/*.h`; the SDK sysroot has almost none |
| `libffi`, `pcre2` | glib's closure and `GRegex` |
| `glib` | libvips core |
| `expat` | libvips XML metadata |
| `jpeg` (libjpeg-turbo) | JPEG, and libtiff's JPEG compression |
| `spng` | PNG read **and** write |
| `webp` | WebP, plus its own `libsharpyuv` |
| `tiff` | TIFF, Deflate + JPEG compression only |
| `exif`, `iptc` | libvips metadata, and SwiftExif directly |
| `vips` | the thing Munin actually calls |

`zlib` needs no stage — the SDK sysroot ships `libz.a` and `zlib.pc`, and
`env.sh` rewrites that `.pc`'s dead `prefix=/home/build-user/...` path.

Not included, deliberately: **HEIC/AVIF** (drags in libheif plus a C++
HEVC/AV1 decoder), **libimagequant** (only needed for paletted PNG output),
**lcms2**, and libtiff's exotic codecs (zstd, lzma, jbig, lerc, libdeflate).

## Things that look removable and are not

There are about eight of them — the `--gcc-toolchain` and `-resource-dir`
flags, the missing `sys_root`, the `func_names` sed, `-Dmodules=disabled`,
`nasm`, `-lsharpyuv`/`-lgmodule-2.0`, the flattened `vips.pc`. Each one is a
reproduced failure and each is explained in a comment at the point of use in
`env.sh` and `build.sh`. Read them there rather than here; a second copy would
only drift.

## Bumping a C library version

Versions live in one block at the top of `build.sh`, and every download is
checked against the `SHA256` table just below it. After a bump: update the
version, update its hash, delete the stage's stamp (or the whole `out/<arch>`),
and re-run both arches — `make build-musl-sysroot` runs `verify.sh` for you. If
you add a library that libvips links, add its `-l` to `write_flat_vips_pc`
**before** the libraries it depends on, and add its archive to `EXPECTED` in
`verify.sh`.

Getting the new hash right is the part worth care. `sha256sum` on the tarball
you just downloaded proves only that the bytes arrived intact — if the download
was already the wrong file, it certifies the wrong file. Cross-check against
somebody else who published a hash of the same tarball:

- an upstream sidecar, where one exists — GNOME ships
  `https://download.gnome.org/sources/glib/<series>/glib-<ver>.sha256sum`;
- a distro that packages the identical tarball — Alpine's
  `https://gitlab.alpinelinux.org/alpine/aports/-/raw/master/main/<pkg>/APKBUILD`
  (`sha512sums=`, so compare with `sha512sum`; older versions live on the
  `<release>-stable` branches), or Arch's
  `https://gitlab.archlinux.org/archlinux/packaging/packages/<pkg>/-/raw/<ver>-<rel>/PKGBUILD`;
- upstream's detached signature, when nobody packages that archive format —
  `expat-<ver>.tar.xz.asc` on the libexpat GitHub release, verified against key
  `3176EF7DB2367F1FCA4F306B1F9B0E909AF37285`.

Every hash currently in the table was checked that way.

Alpine's `linux-headers` is the one download not pinned by revision: `build.sh`
reads the current `-rN` out of the branch `APKINDEX`, because the Alpine CDN
serves only the newest revision and a pinned one 404s the day it is rebuilt.
The kernel UAPI version (`KHDRS_VER`) *is* pinned, and a mismatch is a hard
failure with instructions.

## Bumping Swift and the Static Linux SDK

One place carries the pin:

- `Dockerfile` — `ARG SDK_VERSION` / `ARG SDK_URL` / `ARG SDK_CHECKSUM`, and
  the `FROM swift:<version>` base.

`env.sh` globs the installed bundle and the musl sysroot inside it, so it needs
no edit and fails loudly if it finds anything other than exactly one. The
workflows need no edit either: `scripts/build-static.sh` runs `swift` inside
this image, so `static-release.yml` gets the toolchain and the SDK from it
transitively. `.github/workflows/swift-ci.yml` pins a Swift toolchain of its
own for the *glibc* build and `swift test`; that version should move with
`FROM swift:<version>` here, but it has nothing to do with the SDK.

The checksum is the awkward part: **swift.org publishes no `.sha256` sidecar**
next to the artifactbundle, so there is nothing to `curl` alongside the
download. The durable, reviewable source is the swift.org website's own data
file, which carries a `static_sdk` entry per release:

```sh
curl -fsSL https://raw.githubusercontent.com/swiftlang/swift-org-website/main/_data/builds/swift_releases.yml \
  | grep -A2 'platform: static-sdk'
```

Entries are in release order, one per Swift release, so the last one is newest;
find the block under the `name: swift-6.x.y-RELEASE` you are moving to. The
value currently pinned in the `Dockerfile`
(`fac05271…97ad`, Swift 6.3.1) came from there.

Computing it yourself with `shasum -a 256` on a tarball you just downloaded is
not a check — it only proves the bytes arrived intact. Take the value from
`swift_releases.yml` (or from swift.org's release page, which renders the same
data), then let `swift sdk install --checksum` verify the download.

After a bump, wipe the whole output tree (`rm -rf $MUSL_WORK/out`) rather than
individual stamps: everything here is compiled against the SDK's musl headers
and `libc.a`, so every stage is downstream of the SDK. Then re-run
`make build-musl-sysroot` and rebuild the Swift binaries from scratch — a stale
`.build/<triple>` mixing old and new objects links but is not something you
want to ship.
