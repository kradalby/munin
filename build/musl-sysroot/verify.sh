#!/usr/bin/env bash
# Assert that a finished prefix is a *complete* C closure, before anything
# downstream depends on it. `make build-musl-sysroot` runs this per arch.
#
#   docker run --rm -v "$PWD/build/musl-sysroot:/recipe:ro" \
#                   -v "$PWD/.build/musl-sysroot:/work" \
#                   munin-musl bash /recipe/verify.sh x86_64
#
# Scope is deliberately narrow: only the things nothing else can catch.
# scripts/build-static.sh already proves the real binary is static, the right
# machine and free of DT_NEEDED, and scripts/smoke-static.sh already decodes
# and re-encodes JPEG, PNG, WebP and TIFF with it. What neither can see is a
# closure that is *narrower than intended but still links* -- a missing archive
# whose format then fails at a user's runtime, a JPEG codec that quietly lost
# SIMD, a vips.pc that SwiftPM's own parser will mangle. CI bakes this prefix
# into an image tagged by recipe hash and trusts it from then on, so those have
# to fail here.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="${1:?usage: verify.sh <x86_64|aarch64>}"
# shellcheck source=env.sh
source "$HERE/env.sh" "$ARCH"

case "$ARCH" in
  x86_64)  WANT_FORMAT=elf64-x86-64 ;;
  aarch64) WANT_FORMAT=elf64-littleaarch64 ;;
esac

# The complete expected closure. A missing entry here means a silently narrower
# binary later -- a format that simply fails at runtime -- so it is fatal.
EXPECTED=(
  libexif libexpat libffi libgio-2.0 libgirepository-2.0 libglib-2.0
  libgmodule-2.0 libgobject-2.0 libgthread-2.0 libiptcdata libjpeg
  libpcre2-8 libpcre2-posix libsharpyuv libspng libtiff libvips
  libwebp libwebpdemux libwebpmux
)

fail=0
bad() { echo "!! $*" >&2; fail=1; }

echo "== archives present, and $WANT_FORMAT =="
for name in "${EXPECTED[@]}"; do
  a="$PREFIX/lib/${name}.a"
  if [ ! -e "$a" ]; then
    printf '%-24s MISSING\n' "$name"; fail=1; continue
  fi
  # `|| true`: grep -m1 exits early and SIGPIPEs objdump, which under
  # `set -o pipefail` would abort the whole script on the first large archive.
  fmt=$({ "$OBJDUMP" -f "$a" 2>/dev/null || true; } | grep -m1 -o 'file format .*' | cut -d' ' -f3)
  printf '%-24s %s\n' "$name" "$fmt"
  [ "$fmt" = "$WANT_FORMAT" ] || bad "$name is $fmt, wanted $WANT_FORMAT"
done

echo
echo "== libjpeg-turbo SIMD =="
# Read the archive, not $LOGDIR/jpeg-cmake.log: on a stamped or resumed build
# the log may be from another run or absent entirely, and this check exists
# precisely for the case where nobody watched the build. libjpeg-turbo only
# descends into simd/ when WITH_SIMD is on, so a scalar build has no jsimd*
# member at all -- on either arch, x86_64 via nasm and aarch64 via Neon
# intrinsics. Scalar JPEG costs roughly 2-4x on Munin's hot path.
members=$("$AR" t "$PREFIX/lib/libjpeg.a")
simd=$(printf '%s\n' "$members" | grep -c -e '^jsimd' -e -neon -e '\.asm\.o$' || true)
if [ "$simd" -gt 0 ]; then
  echo "libjpeg.a carries $simd SIMD objects"
else
  bad "libjpeg.a has no jsimd*/*-neon/*.asm members -- scalar codec; check nasm in the image"
fi

echo
echo "== vips.pc is flat and fully resolvable =="
# Two failures this catches, both silent otherwise. (1) A `Requires:` line:
# SwiftPM parses .pc files itself and expands Requires in declaration order,
# which meson writes backwards for a single-pass static link -- and drops every
# cflag if one entry does not resolve. (2) A `-l` naming an archive that is not
# in the closure: the Swift link would fail with undefined references pointing
# at anything but the cause.
req=$("$PKG_CONFIG" --print-requires vips || true)
if [ -n "$req" ]; then bad "vips.pc has Requires: $req"; else echo "Requires: (none)"; fi
libs=$("$PKG_CONFIG" --libs vips)
echo "cflags: $("$PKG_CONFIG" --cflags vips)"
echo "libs:   $libs"
for l in $libs; do
  case "$l" in -l*) ;; *) continue ;; esac
  n="lib${l#-l}.a"
  [ -e "$PREFIX/lib/$n" ] || [ -e "$SYSROOT/usr/lib/$n" ] ||
    bad "vips.pc names $l but neither $PREFIX/lib/$n nor $SYSROOT/usr/lib/$n exists"
done

echo
if [ "$fail" = 0 ]; then echo "== OK ($ARCH) =="; else echo "== FAILED ($ARCH) =="; fi
exit "$fail"
