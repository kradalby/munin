#!/usr/bin/env bash
# Build a fully static Linux `munin` (musl, no PT_INTERP, no DT_NEEDED).
#
#   scripts/build-static.sh <amd64|arm64> [debug|release]
#
# Defaults to release. Debug is what CI attaches to every run so a change can
# be downloaded and tried; it keeps its symbols (no -Xlinker -s) and is roughly
# three times the size.
#
# Requires the C closure from build/musl-sysroot to have been built first
# (`make build-musl-sysroot`). Both architectures cross-compile from the same
# x86_64 container; there is no arm64 runner and no qemu in this path.
#
# The Swift build runs *inside* that container on purpose:
#
#   * the .pc files the C closure installs carry absolute in-container paths;
#   * SwiftPM's built-in .pc parser reads HOST pkg-config directories during a
#     `--swift-sdk` build and ignores PKG_CONFIG_LIBDIR entirely, so the build
#     must happen somewhere with no `-dev` packages installed. In particular,
#     never run this inside `nix develop`.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER="${DOCKER:-docker}"
MUSL_IMAGE="${MUSL_IMAGE:-munin-musl}"
MUSL_WORK="${MUSL_WORK:-$REPO/.build/musl-sysroot}"

case "${1:-}" in
  amd64|x86_64)  ARCH=x86_64;  MACHINE='x86-64'  ;;
  arm64|aarch64) ARCH=aarch64; MACHINE='aarch64' ;;
  *) echo "usage: $(basename "$0") <amd64|arm64> [debug|release]" >&2; exit 2 ;;
esac

case "${2:-release}" in
  release) CONFIG=release; STRIP=1 ;;
  debug)   CONFIG=debug;   STRIP=  ;;
  *) echo "usage: $(basename "$0") <amd64|arm64> [debug|release]" >&2; exit 2 ;;
esac

TRIPLE="${ARCH}-swift-linux-musl"
PREFIX="/work/out/${ARCH}"
UIDGID="$(id -u):$(id -g)"

# libvips.a, not the prefix or its pkgconfig dir: env.sh creates those before
# any library is built, and build.sh writes the flattened vips.pc at the end of
# every invocation including a partial one -- so a half-staged sysroot passes
# any weaker check and the failure resurfaces as a wall of undefined references
# from the Swift link. vips is the last stage, so its archive means the whole
# closure landed.
if [ ! -f "$MUSL_WORK/out/$ARCH/lib/libvips.a" ]; then
  echo "error: no complete musl sysroot for $ARCH at $MUSL_WORK/out/$ARCH" >&2
  echo "       (lib/libvips.a is missing; an interrupted build leaves the" >&2
  echo "        prefix in place with only some libraries in it)" >&2
  echo "       run 'make build-musl-sysroot' first -- it resumes from stamps" >&2
  exit 1
fi

echo "== building munin for $TRIPLE ($CONFIG)"

# Three flags below are each a reproduced requirement, not a preference:
#
#   --swift-sdk <triple>   Spelled out in full. Passing the artifact bundle id
#                          instead silently selects aarch64 on an x86_64 host,
#                          with only a warning -- which is why this script
#                          asserts the machine type afterwards.
#   -Xcc -I$PREFIX/include SwiftExif's plain C target `ExifFormat` does
#                          `#include <libexif/exif-entry.h>` and receives no
#                          pkg-config cflags. Without this the build dies with
#                          "'libexif/exif-entry.h' file not found".
#   -Xlinker -s            Strips at link time (~180 MB -> ~70 MB). Safe only
#                          because no build-tool plugin exists any more to leak
#                          the flag into a host tool link. Release only —
#                          stripping a debug binary defeats its purpose.
#
# PKG_CONFIG_PATH is likewise the only knob that works: `swift sdk configure
# --include-search-path/--library-search-path` are recorded by SwiftPM 6.3.1
# and then never passed to the compiler or linker.
$DOCKER run --rm -i \
  -v "$REPO:/src" \
  -v "$MUSL_WORK:/work" \
  -w /src \
  -e "PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig" \
  -e "TRIPLE=$TRIPLE" -e "PREFIX=$PREFIX" -e "MACHINE=$MACHINE" -e "UIDGID=$UIDGID" \
  -e "CONFIG=$CONFIG" -e "STRIP=${STRIP:-}" \
  "$MUSL_IMAGE" bash -euo pipefail -s <<'INNER'
swift build -c "$CONFIG" --swift-sdk "$TRIPLE" \
  -Xcc -I"$PREFIX/include" \
  ${STRIP:+-Xlinker -s}

BIN=".build/$TRIPLE/$CONFIG/munin"
file "$BIN"

fail() { echo "FAIL: $*" >&2; exit 1; }
if readelf -lW "$BIN" | grep -q INTERP; then fail "binary has PT_INTERP"; fi
if readelf -dW "$BIN" | grep -q NEEDED; then fail "binary has DT_NEEDED"; fi
if ! file "$BIN" | grep -q "$MACHINE"; then fail "wrong architecture (wanted $MACHINE)"; fi
echo "OK: static, no PT_INTERP, no DT_NEEDED, $(stat -c %s "$BIN") bytes"

# The container runs as root (the Static SDK lives in /root/.swiftpm), so hand
# the build products back. .build/musl-sysroot is skipped deliberately: it is
# the multi-gigabyte scratch mount, not a build product.
chown "$UIDGID" /src/.build /src/Package.resolved 2>/dev/null || true
find /src/.build -mindepth 1 -maxdepth 1 ! -name musl-sysroot \
  -exec chown -R "$UIDGID" {} + 2>/dev/null || true
INNER

echo "== $REPO/.build/$TRIPLE/$CONFIG/munin"
