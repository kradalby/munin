#!/usr/bin/env bash
# Acceptance test for a statically linked `munin`.
#
#   scripts/smoke-static.sh <binary> --arch amd64|arm64 [--reference DIR]
#                                    [--native]
#
# Stands in for `swift test`, which cannot run against the Static SDK at all:
# it ships no test framework at all, and swift-testing does not compile for
# musl. Unit tests stay on the glibc builds.
#
# What it proves:
#
#   1. The binary runs under busybox with an empty environment -- no host libc,
#      no /usr/share, no locale, no fontconfig. The portability assertion.
#   2. It builds the whole example/ gallery and exits 0.
#   3. The tree is byte-identical to a reference.
#   4. PNG, WebP and TIFF survived static linking -- example/ is all JPEG, so
#      1-3 pass on a libvips that can only do JPEG.
#
# Step 3 is only meaningful because the staged copy's mtimes are pinned first
# (see normalise-mtimes.sh). `--reference DIR` compares against some other
# generated tree instead -- one arch against the other, or across a nixpkgs
# bump. Not a dynamic build's output: only the two musl triples are
# byte-identical to each other.
#
# `--native` drops the container and runs the binary directly, for the nix
# checks: the sandbox is already a stricter empty environment, and no docker
# daemon is reachable from a derivation. SMOKE_RUNNER names a qemu-user binary
# for a foreign arch, which needs no binfmt registration.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCKER="${DOCKER:-docker}"
SMOKE_IMAGE="${SMOKE_IMAGE:-busybox}"

USAGE="usage: $(basename "$0") <binary> --arch amd64|arm64 [--reference DIR] [--native]"

BIN=""
ARCH=""
NATIVE=""
SMOKE_RUNNER="${SMOKE_RUNNER:-}"
REFERENCE="$REPO/example/content"

while [ $# -gt 0 ]; do
  case "$1" in
    --arch)      ARCH="${2:?--arch needs a value}"; shift 2 ;;
    --reference) REFERENCE="${2:?--reference needs a value}"; shift 2 ;;
    --native)    NATIVE=1; shift ;;
    -h|--help)   echo "$USAGE"; exit 0 ;;
    -*)          echo "unknown option: $1" >&2; exit 2 ;;
    *)           BIN="$1"; shift ;;
  esac
done

[ -n "$BIN" ] || { echo "$USAGE" >&2; exit 2; }
[ -f "$BIN" ] || { echo "error: no such binary: $BIN" >&2; exit 1; }
BIN="$(cd "$(dirname "$BIN")" && pwd)/$(basename "$BIN")"

# Not inferred from the binary path: the whole test is that this binary runs
# somewhere it was not built, so the path is a bad witness for the arch.
case "$ARCH" in
  amd64|arm64) ;;
  *) echo "error: --arch must be amd64 or arm64" >&2; exit 2 ;;
esac

NORMALISE="$REPO/scripts/normalise-mtimes.sh"

PLATFORM="linux/$ARCH"

# A foreign-arch image needs a binfmt handler registered with the F (fix
# binary) flag; without it the kernel resolves the interpreter inside the
# container's mount namespace and every exec fails with ENOENT. NixOS'
# boot.binfmt.emulatedSystems registers P only.
if [ -z "$NATIVE" ] && ! $DOCKER run --rm --platform "$PLATFORM" "$SMOKE_IMAGE" true 2>/dev/null; then
  echo "error: cannot run $PLATFORM containers" >&2
  echo "       a binfmt handler registered with the F flag is required; install one with:" >&2
  echo "         $DOCKER run --privileged --rm tonistiigi/binfmt --install $ARCH" >&2
  echo "       (check the current one with: cat /proc/sys/fs/binfmt_misc/*aarch64*)" >&2
  exit 1
fi

if [ -n "$NATIVE" ]; then
  SANDBOX_DESC="directly with an empty environment"
else
  SANDBOX_DESC="under busybox with an empty environment"
fi

WORK="$(mktemp -d)"
FMT="$(mktemp -d)"
LOG="$(mktemp)"
cleanup() {
  # The container writes as root; hand the trees back before removing them.
  # Native runs write as the invoking user and need no such thing.
  [ -n "$NATIVE" ] || $DOCKER run --rm -v "$WORK:/w" -v "$FMT:/f" "$SMOKE_IMAGE" \
    chown -R "$(id -u):$(id -g)" /w /f >/dev/null 2>&1 || true
  rm -rf "$WORK" "$FMT" "$LOG"
}
trap cleanup EXIT

# Nothing inherited: env -i, no host libc, no /usr/share, no locale or tz
# database, no fontconfig. The encoded count lands in $ENCODED.
ENCODED=""
run_munin() {
  local gallery="$1"
  set +e
  if [ -n "$NATIVE" ]; then
    # ${SMOKE_RUNNER:+...} stays unquoted-empty when unset, so no empty
    # argv[0] reaches env.
    (cd "$gallery" && env -i ${SMOKE_RUNNER:+"$SMOKE_RUNNER"} "$BIN") 2>&1 | tee "$LOG"
  else
    $DOCKER run --rm --platform "$PLATFORM" \
      -v "$gallery:/gallery" \
      -v "$BIN:/munin:ro" \
      -w /gallery \
      "$SMOKE_IMAGE" env -i /munin 2>&1 | tee "$LOG"
  fi
  local status="${PIPESTATUS[0]}"
  set -e
  [ "$status" -eq 0 ] || { echo "FAIL: munin exited $status" >&2; exit 1; }

  ENCODED="$(sed -n 's/^[[:space:]]*\([0-9][0-9]*\) photos has been encoded$/\1/p' "$LOG" | tail -1)"
  [ -n "$ENCODED" ] || { echo "FAIL: no 'photos has been encoded' line in output" >&2; exit 1; }
  [ "$ENCODED" -gt 0 ] || { echo "FAIL: $ENCODED photos encoded" >&2; exit 1; }
}

# cp -a carries the checkout's mtimes over, so pin them on the copy. The
# repo's example/album is untouched: cp makes new inodes.
echo "== staging example/ into $WORK"
cp -a "$REPO/example/." "$WORK/"
rm -rf "$WORK/content"
"$NORMALISE" "$WORK/album"

echo "== running $(basename "$BIN") on $PLATFORM $SANDBOX_DESC"
run_munin "$WORK"

FILES="$(find "$WORK/content" -type f | wc -l)"
echo "== $ENCODED photos encoded, $FILES files generated"
[ "$FILES" -gt 0 ] || { echo "FAIL: content/ is empty" >&2; exit 1; }

[ -d "$REFERENCE" ] || { echo "FAIL: reference not a directory: $REFERENCE" >&2; exit 1; }
echo "== diffing against $REFERENCE"
if ! diff -rq "$REFERENCE" "$WORK/content"; then
  echo "FAIL: generated tree differs from the reference" >&2
  echo "      if the difference is in modifiedDate, regenerate the baseline:" >&2
  echo "      scripts/regen-example-content.sh <munin-binary>" >&2
  exit 1
fi
echo "== identical to reference"

# --- PNG / WebP / TIFF ------------------------------------------------------
#
# A decoder that links but does not register fails at the user's runtime
# rather than at our build, so decode a real file in each format. Munin names
# each output after its source extension, so one run covers load and save.
# The fixtures come from other people's encoders (scripts/testdata/README.md),
# which is what makes this a decode test and not a round-trip against
# ourselves.
FIXTURES="$REPO/scripts/testdata/formats"

# First four bytes as hex, or bytes [$3, $3+$2). file(1) may not exist.
magic() { od -An -v -tx1 -N "${2:-4}" -j "${3:-0}" "$1" | tr -d ' \n'; }

echo "== staging $FIXTURES into $FMT"
cp -a "$FIXTURES/." "$FMT/"
rm -rf "$FMT/content"
"$NORMALISE" "$FMT/album"

echo "== decoding PNG, WebP and TIFF on $PLATFORM $SANDBOX_DESC"
run_munin "$FMT"
[ "$ENCODED" -eq 3 ] || { echo "FAIL: expected 3 photos encoded, got $ENCODED" >&2; exit 1; }

OUT="$FMT/content/formats/Formats"
for f in png_sample_100.png webp_sample_100.webp tiff_sample_100.tif; do
  [ -s "$OUT/$f" ] || { echo "FAIL: $f missing or empty" >&2; exit 1; }
done

# PNG signature; RIFF....WEBP container; TIFF byte-order mark (either endianness).
[ "$(magic "$OUT/png_sample_100.png")" = "89504e47" ] ||
  { echo "FAIL: png_sample_100.png is not a PNG" >&2; exit 1; }
[ "$(magic "$OUT/webp_sample_100.webp")" = "52494646" ] &&
  [ "$(magic "$OUT/webp_sample_100.webp" 4 8)" = "57454250" ] ||
  { echo "FAIL: webp_sample_100.webp is not a WebP" >&2; exit 1; }
case "$(magic "$OUT/tiff_sample_100.tif")" in
  49492a00|4d4d002a) ;;
  *) echo "FAIL: tiff_sample_100.tif is not a TIFF" >&2; exit 1 ;;
esac
echo "== PNG, WebP and TIFF each decoded and re-encoded"

echo "PASS"
