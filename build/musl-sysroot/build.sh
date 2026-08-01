#!/usr/bin/env bash
# Cross-build Munin's whole C dependency closure as static musl archives for
# the Swift Static Linux SDK.
#
#   docker build -t munin-musl build/musl-sysroot
#   docker run --rm \
#     -v "$PWD/build/musl-sysroot:/recipe:ro" \
#     -v "$PWD/.build/musl-sysroot:/work" \
#     munin-musl bash /recipe/build.sh x86_64
#
# The recipe and the output tree are separate mounts on purpose: the recipe is
# checked in, the output tree is multi-gigabyte scratch. $WORK (default /work)
# is where sources, build dirs, logs and the finished prefixes land; the script
# itself may live anywhere.
#
#   ./build.sh <arch> [stage ...]      arch = x86_64 | aarch64
#
# With no stages, builds every stage in dependency order. Idempotent: each
# stage drops a stamp under $WORK/out/<arch>/.stamps and is skipped if present.
# Pass FORCE=1 to rebuild regardless.
#
# Stage order is a dependency order, not a preference:
#   khdrs  -> everything (Alpine's linux/*.h and asm/*.h; see env note below)
#   libffi -> glib (gobject closures)
#   pcre2  -> glib (GRegex)
#   glib   -> libvips
#   expat  -> libvips (SVG-less XML metadata parsing)
#   jpeg   -> libvips, libtiff
#   spng   -> libvips        (needs zlib)
#   webp   -> libvips
#   tiff   -> libvips        (needs zlib + jpeg)
#   exif   -> libvips, and SwiftExif directly
#   iptc   -> libvips, and SwiftExif directly
#   vips   -> Munin
#
# zlib needs no stage: the SDK sysroot ships libz.a and zlib.pc already, and
# env.sh rewrites that .pc's dead `prefix=/home/build-user/...` path.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCH="${1:?usage: build.sh <x86_64|aarch64> [stage ...]}"
shift || true

# shellcheck source=env.sh
source "$HERE/env.sh" "$ARCH"

STAMPS="$PREFIX/.stamps"
mkdir -p "$STAMPS"
JOBS="${JOBS:-$(nproc)}"

# Versions in one place.
ALPINE_REL=v3.22
KHDRS_VER=6.14.2          # kernel UAPI version; the -rN is resolved, see stage_khdrs
LIBFFI_VER=3.5.2
PCRE2_VER=10.47
GLIB_VER=2.86.5
GLIB_SERIES=${GLIB_VER%.*}
EXPAT_VER=2.7.3
JPEG_VER=3.1.2
SPNG_VER=0.7.4
WEBP_VER=1.6.0
TIFF_VER=4.7.0
EXIF_VER=0.6.24
IPTC_VER=1.0.5
VIPS_VER=8.16.1

# One sha256 per download, for the same reason the Dockerfile pins the Swift
# SDK by checksum: a silent upstream republish must not change what we link
# against. It matters more here than it looks, because CI tags the baked
# sysroot image with hashFiles('build/musl-sysroot/**') -- so without these,
# one tag could map to two different C closures and nobody would notice.
#
# These are not "whatever we happened to download". Each was cross-checked
# against a third party publishing a hash of the same file: GNOME's own
# .sha256sum sidecar (glib); Alpine aports' sha512sums (libffi, pcre2, tiff,
# libexif, libspng, libwebp, libiptcdata, vips); Arch's packaging repo
# (libjpeg-turbo); and upstream's detached GPG signature for expat, whose
# .tar.xz no distro packages. See README.md, "Bumping a C library version",
# for how to redo that on a bump.
declare -A SHA256=(
  [libffi-3.5.2.tar.gz]=f3a3082a23b37c293a4fcd1053147b371f2ff91fa7ea1b2a52e335676bac82dc
  [pcre2-10.47.tar.bz2]=47fe8c99461250d42f89e6e8fdaeba9da057855d06eb7fc08d9ca03fd08d7bc7
  [glib-2.86.5.tar.xz]=ce85a947bb8b3c0204dbeff79aec39bcb46371c6fafb64ba5b8726c71e038d5f
  [expat-2.7.3.tar.xz]=71df8f40706a7bb0a80a5367079ea75d91da4f8c65c58ec59bcdfbf7decdab9f
  [libjpeg-turbo-3.1.2.tar.gz]=8f0012234b464ce50890c490f18194f913a7b1f4e6a03d6644179fa0f867d0cf
  [libspng-0.7.4.tar.gz]=47ec02be6c0a6323044600a9221b049f63e1953faf816903e7383d4dc4234487
  [libwebp-1.6.0.tar.gz]=e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564
  [tiff-4.7.0.tar.gz]=67160e3457365ab96c5b3286a0903aa6e78bdc44c4bc737d2e486bcecb6ba976
  [libexif-0.6.24.tar.bz2]=d47564c433b733d83b6704c70477e0a4067811d184ec565258ac563d8223f6ae
  [libiptcdata-1.0.5.tar.gz]=c094d0df4595520f194f6f47b13c7652b7ecd67284ac27ab5f219bc3985ea29e
  [vips-8.16.1.tar.xz]=d114d7c132ec5b45f116d654e17bb4af84561e3041183cd4bfd79abfb85cf724
  # Alpine's linux-headers: keyed on the full apk name because stage_khdrs
  # resolves the -rN itself. A revision Alpine has not built yet is handled
  # there, not here.
  [x86_64-linux-headers-6.14.2-r0.apk]=b0d7184f0e8d926961b82dff3d8a6a1f85db100dfc97e3fa1e6a25bbe9fd0f71
  [aarch64-linux-headers-6.14.2-r0.apk]=08bc7264055d4ceca249e21f47875ccd7ae2dc7eaf49e235a83b1059e06d9089
)

die() { echo "!! $*" >&2; exit 1; }

# ------------------------------------------------------------- helpers ------
# Verification runs on the cached file too, not just on a fresh download: a
# truncated or corrupted $WORK/dl entry would otherwise be reused forever,
# since the cache check is only `-s`.
fetch() { # url [filename] -> path
  local url="$1" out="${2:-$(basename "$1")}"
  local want="${SHA256[$out]:-}"
  [ -n "$want" ] || die "no sha256 recorded for $out -- add one to the SHA256 table in build.sh"
  if [ ! -s "$WORK/dl/$out" ]; then
    echo "-- fetching $out" >&2
    curl -fsSL -o "$WORK/dl/$out.part" "$url" \
      || die "download failed: $url"
    mv "$WORK/dl/$out.part" "$WORK/dl/$out"
  fi
  if [ "$want" != unverified ] &&
     ! printf '%s  %s\n' "$want" "$WORK/dl/$out" | sha256sum -c --status -; then
    die "sha256 mismatch for $out
     want $want
     got  $(sha256sum < "$WORK/dl/$out" | cut -d' ' -f1)
     from $url
     If upstream really did republish, check the new hash against a third
     party (see the SHA256 table's comment) before changing it here.
     Otherwise delete $WORK/dl/$out and retry."
  fi
  echo "$WORK/dl/$out"
}

unpack() { # tarball dirname -> path
  local tb="$1" dir="$2"
  if [ ! -d "$SRC/$dir" ]; then
    echo "-- unpacking $(basename "$tb")" >&2
    tar -C "$SRC" -xf "$tb"
  fi
  echo "$SRC/$dir"
}

need_stage() { # name
  [ "${FORCE:-0}" = 1 ] && return 0
  [ -e "$STAMPS/$1" ] && { echo "== skip $1 (stamped)"; return 1; }
  return 0
}

stamp() { touch "$STAMPS/$1"; }

run() { # logname, command...
  local log="$LOGDIR/$1.log"; shift
  echo "   \$ $*" | tee -a "$log"
  if ! "$@" >>"$log" 2>&1; then
    echo "!! FAILED (see $log)"
    tail -n 80 "$log"
    return 1
  fi
}

# CMake toolchain file, for the one dependency (libjpeg-turbo) that has no
# autotools or meson build. FIND_ROOT_PATH_MODE_PROGRAM=NEVER keeps cmake from
# picking up host binaries as if they were target ones.
CMAKE_TC="$WORK/cross/${TRIPLE}.cmake"
cat > "$CMAKE_TC" <<CMEOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR ${ARCH})
set(CMAKE_C_COMPILER ${TOOLBIN}/${TRIPLE}-clang)
set(CMAKE_CXX_COMPILER ${TOOLBIN}/${TRIPLE}-clang++)
set(CMAKE_AR ${TOOLBIN}/${TRIPLE}-ar)
set(CMAKE_RANLIB ${TOOLBIN}/${TRIPLE}-ranlib)
set(CMAKE_FIND_ROOT_PATH ${PREFIX};${SYSROOT}/usr)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_EXE_LINKER_FLAGS "-static")
CMEOF

# Autotools cross-build boilerplate shared by every ./configure stage.
conf_common=(
  --host="$TRIPLE" --build="$(uname -m)-pc-linux-gnu"
  --prefix="$PREFIX" --libdir="$PREFIX/lib"
  --disable-shared --enable-static
)

# ------------------------------------------------------- kernel headers -----
# The Static Linux SDK sysroot ships only the six linux/*.h files musl itself
# installs (capability, futex, limits, random, sockios, vm_sockets) and no
# asm/ or asm-generic/ at all. Anything that includes <linux/types.h> --
# libffi's static trampoline, glib's gio netlink monitor, libvips' io_uring
# probes -- fails to compile. Drop Alpine's per-arch linux-headers package
# into the staging prefix; -I$PREFIX/include precedes the sysroot include dir,
# so these win where they overlap, exactly as they do on Alpine.
#
# The package revision (-rN) is NOT pinned, deliberately. Alpine's CDN serves
# only the current revision of a package per branch, so a hardcoded -r0 404s
# the day Alpine rebuilds it -- taking out the very first stage of every cold
# build, for every new contributor and for CI. So: read the current version out
# of the branch APKINDEX. What stays pinned is KHDRS_VER, the kernel UAPI
# version, which is the part that decides what these headers actually say; a
# revision bump is a repackage of the same kernel's headers. If Alpine moves to
# a different kernel version this fails loudly rather than silently swapping
# the headers underneath the closure.
khdrs_pkgver() { # -> e.g. 6.14.2-r0
  local idx="$WORK/dl/APKINDEX-${ALPINE_REL}-${ARCH}.tar.gz" v
  curl -fsSL -o "$idx" \
    "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_REL}/main/${ARCH}/APKINDEX.tar.gz" \
    || die "cannot read Alpine ${ALPINE_REL} ${ARCH} APKINDEX -- network, or the branch is gone"
  v=$(tar -xzOf "$idx" APKINDEX |
        awk '/^P:linux-headers$/ {f=1; next} f && /^V:/ {print substr($0,3); exit}')
  [ -n "$v" ] || die "Alpine ${ALPINE_REL}/main/${ARCH} lists no linux-headers package"
  echo "$v"
}

stage_khdrs() {
  need_stage khdrs || return 0
  local pkgver apk key
  pkgver=$(khdrs_pkgver)
  [ "${pkgver%-r*}" = "$KHDRS_VER" ] || die \
"Alpine ${ALPINE_REL} now ships linux-headers ${pkgver}, but build.sh pins
     KHDRS_VER=${KHDRS_VER}. Bump KHDRS_VER and record the new apks' sha256
     in the SHA256 table, or move ALPINE_REL to a branch still on ${KHDRS_VER}."
  apk="linux-headers-${pkgver}.apk"
  key="${ARCH}-${apk}"
  echo "-- linux-headers ${pkgver} (${ALPINE_REL}/main/${ARCH})"
  if [ -z "${SHA256[$key]:-}" ]; then
    echo "!! no sha256 recorded for ${key} -- Alpine has rebuilt the package" >&2
    echo "!! since this recipe was last touched. Same kernel UAPI version" >&2
    echo "!! (${KHDRS_VER}), so continuing unverified; record its sha256 in" >&2
    echo "!! build.sh's SHA256 table to restore verification." >&2
    SHA256[$key]=unverified
  fi
  local path
  path=$(fetch "https://dl-cdn.alpinelinux.org/alpine/${ALPINE_REL}/main/${ARCH}/${apk}" "$key")
  # .apk is a concatenation of gzip streams; GNU tar handles it directly.
  run khdrs tar -C "$PREFIX" --strip-components=1 -xzf "$path" usr/include
  stamp khdrs
}

# --------------------------------------------------------------- libffi -----
stage_libffi() {
  need_stage libffi || return 0
  local tb src bld
  tb=$(fetch "https://github.com/libffi/libffi/releases/download/v${LIBFFI_VER}/libffi-${LIBFFI_VER}.tar.gz")
  src=$(unpack "$tb" "libffi-${LIBFFI_VER}")
  bld="$BUILDDIR/libffi"; rm -rf "$bld"; mkdir -p "$bld"
  ( cd "$bld" && run libffi-configure "$src/configure" "${conf_common[@]}" \
      --disable-docs --disable-multi-os-directory )
  ( cd "$bld" && run libffi-make make -j"$JOBS" )
  ( cd "$bld" && run libffi-install make install )
  stamp libffi
}

# ---------------------------------------------------------------- pcre2 -----
stage_pcre2() {
  need_stage pcre2 || return 0
  local tb src bld
  tb=$(fetch "https://github.com/PCRE2Project/pcre2/releases/download/pcre2-${PCRE2_VER}/pcre2-${PCRE2_VER}.tar.bz2")
  src=$(unpack "$tb" "pcre2-${PCRE2_VER}")
  bld="$BUILDDIR/pcre2"; rm -rf "$bld"; mkdir -p "$bld"
  ( cd "$bld" && run pcre2-configure "$src/configure" "${conf_common[@]}" \
      --enable-unicode --enable-pcre2-8 --disable-pcre2-16 --disable-pcre2-32 )
  ( cd "$bld" && run pcre2-make make -j"$JOBS" )
  ( cd "$bld" && run pcre2-install make install )
  stamp pcre2
}

# ----------------------------------------------------------------- glib -----
# Every -D below overrides a glib default that would otherwise pull something
# in from the host or cost real build time; anything already at glib's default
# is not repeated here. `tests` in particular is not cosmetic -- it defaults to
# true and builds a few hundred target test binaries we can never run.
stage_glib() {
  need_stage glib || return 0
  local tb src bld
  tb=$(fetch "https://download.gnome.org/sources/glib/${GLIB_SERIES}/glib-${GLIB_VER}.tar.xz")
  src=$(unpack "$tb" "glib-${GLIB_VER}")
  bld="$BUILDDIR/glib"; rm -rf "$bld"; mkdir -p "$bld"
  run glib-setup meson setup "$bld" "$src" \
      --cross-file "$CROSSFILE" \
      --prefix="$PREFIX" --libdir=lib \
      --default-library=static --prefer-static \
      --buildtype=release \
      -Dwrap_mode=nodownload \
      -Dnls=disabled \
      -Dlibmount=disabled \
      -Dselinux=disabled \
      -Dxattr=false \
      -Dtests=false \
      -Dglib_debug=disabled \
      -Dintrospection=disabled \
      -Dsysprof=disabled
  run glib-build meson compile -C "$bld" -j "$JOBS"
  run glib-install meson install -C "$bld" --no-rebuild
  stamp glib
}

# ---------------------------------------------------------------- expat -----
stage_expat() {
  need_stage expat || return 0
  local tb src bld
  tb=$(fetch "https://github.com/libexpat/libexpat/releases/download/R_${EXPAT_VER//./_}/expat-${EXPAT_VER}.tar.xz")
  src=$(unpack "$tb" "expat-${EXPAT_VER}")
  bld="$BUILDDIR/expat"; rm -rf "$bld"; mkdir -p "$bld"
  ( cd "$bld" && run expat-conf "$src/configure" "${conf_common[@]}" \
      --without-docbook --without-examples --without-tests )
  ( cd "$bld" && run expat-make make -j"$JOBS" )
  ( cd "$bld" && run expat-inst make install )
  stamp expat
}

# ----------------------------------------------------------------- jpeg -----
# SIMD is not optional in spirit: without nasm on x86_64 cmake reports
# "SIMD extensions: None" and quietly builds the scalar codec. The Dockerfile
# installs nasm; this stage refuses to continue if it went missing anyway, so
# the regression cannot ship unnoticed. aarch64 SIMD is Neon intrinsics and
# needs no assembler.
stage_jpeg() {
  need_stage jpeg || return 0
  local tb src bld
  tb=$(fetch "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${JPEG_VER}/libjpeg-turbo-${JPEG_VER}.tar.gz")
  src=$(unpack "$tb" "libjpeg-turbo-${JPEG_VER}")
  bld="$BUILDDIR/jpeg"; rm -rf "$bld"; mkdir -p "$bld"
  if [ "$ARCH" = x86_64 ] && ! command -v nasm >/dev/null 2>&1; then
    echo "!! nasm missing: libjpeg-turbo would build x86_64 without SIMD" >&2
    return 1
  fi
  run jpeg-cmake cmake -S "$src" -B "$bld" -G Ninja \
      -DCMAKE_TOOLCHAIN_FILE="$CMAKE_TC" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_LIBDIR=lib \
      -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_SIMD=ON -DWITH_TURBOJPEG=OFF
  if grep -q 'SIMD extensions: *None' "$LOGDIR/jpeg-cmake.log"; then
    echo "!! libjpeg-turbo configured without SIMD -- see $LOGDIR/jpeg-cmake.log" >&2
    return 1
  fi
  run jpeg-build cmake --build "$bld" -j "$JOBS"
  run jpeg-inst cmake --install "$bld"
  stamp jpeg
}

# ----------------------------------------------------------------- spng -----
# libspng rather than libpng, deliberately. libvips prefers spng when both are
# present (meson.build looks for spng first and only falls back to libpng), and
# since spng 0.7 it covers *write* as well as read -- spngsave.c is a complete
# PNG encoder. The one thing it gives up versus pngsave is palette output,
# which in libvips requires libimagequant regardless, so nothing is lost by not
# also building libpng. Result: PNG support for one small pure-C dependency.
#
# spng's meson emits -DSPNG_STATIC into its .pc when default_library=static
# (a Windows dllimport concern, inert here but harmless).
stage_spng() {
  need_stage spng || return 0
  local tb src bld
  tb=$(fetch "https://github.com/randy408/libspng/archive/refs/tags/v${SPNG_VER}.tar.gz" \
             "libspng-${SPNG_VER}.tar.gz")
  src=$(unpack "$tb" "libspng-${SPNG_VER}")
  bld="$BUILDDIR/spng"; rm -rf "$bld"; mkdir -p "$bld"
  run spng-setup meson setup "$bld" "$src" \
      --cross-file "$CROSSFILE" \
      --prefix="$PREFIX" --libdir=lib \
      --default-library=static --prefer-static \
      --buildtype=release \
      -Dwrap_mode=nodownload \
      -Dstatic_zlib=true \
      -Dbuild_examples=false \
      -Dbenchmarks=false
  run spng-build meson compile -C "$bld" -j "$JOBS"
  run spng-install meson install -C "$bld" --no-rebuild
  stamp spng
}

# ----------------------------------------------------------------- webp -----
# libvips wants three of libwebp's four archives: libwebp (codec), libwebpmux
# and libwebpdemux (container). The fourth, libsharpyuv, is not optional even
# though nothing names it directly -- since libwebp 1.3 the sharp RGB->YUV
# converter lives in its own archive and libwebp.a has undefined references to
# SharpYuvInit/SharpYuvConvert. It reaches the link via libwebp.pc's
# `Requires.private: libsharpyuv` under pkg-config --static, and via -lsharpyuv
# last in the flattened vips.pc below. Omitting it is exactly the
# "undefined reference to `SharpYuvInit'" failure.
#
# Autotools rather than cmake: the autotools build is what generates all four
# .pc files with the Requires.private edges intact.
stage_webp() {
  need_stage webp || return 0
  local tb src bld
  tb=$(fetch "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-${WEBP_VER}.tar.gz")
  src=$(unpack "$tb" "libwebp-${WEBP_VER}")
  bld="$BUILDDIR/webp"; rm -rf "$bld"; mkdir -p "$bld"
  ( cd "$bld" && run webp-conf "$src/configure" "${conf_common[@]}" \
      --enable-libwebpmux --enable-libwebpdemux \
      --disable-libwebpdecoder --disable-libwebpextras \
      --disable-gl --disable-sdl --disable-wic \
      --disable-png --disable-jpeg --disable-tiff --disable-gif )
  ( cd "$bld" && run webp-make make -j"$JOBS" )
  ( cd "$bld" && run webp-inst make install )
  stamp webp
}

# ----------------------------------------------------------------- tiff -----
# Deflate and JPEG compression only. Everything else libtiff can optionally
# link (libdeflate, libzstd, liblzma, libwebp-in-tiff, jbig, lerc) is disabled
# to keep the static closure honest -- each would add an archive to the
# flattened vips.pc for a compression scheme no camera emits. zlib comes from
# the SDK sysroot, so it is found on the default include/library path with no
# --with-zlib-* hints; libjpeg comes from $PREFIX via CPPFLAGS/LDFLAGS.
# --disable-cxx keeps libtiffxx.a (and a second C++ dependency edge) out.
stage_tiff() {
  need_stage tiff || return 0
  local tb src bld
  tb=$(fetch "https://download.osgeo.org/libtiff/tiff-${TIFF_VER}.tar.gz")
  src=$(unpack "$tb" "tiff-${TIFF_VER}")
  bld="$BUILDDIR/tiff"; rm -rf "$bld"; mkdir -p "$bld"
  ( cd "$bld" && run tiff-conf "$src/configure" "${conf_common[@]}" \
      --enable-zlib --enable-jpeg \
      --disable-cxx --disable-libdeflate --disable-zstd --disable-lzma \
      --disable-webp --disable-jbig --disable-lerc \
      --disable-tools --disable-tests --disable-contrib --disable-docs )
  ( cd "$bld" && run tiff-make make -j"$JOBS" )
  ( cd "$bld" && run tiff-inst make install )
  stamp tiff
}

# ----------------------------------------------------------------- exif -----
stage_exif() {
  need_stage exif || return 0
  local tb src bld
  tb=$(fetch "https://github.com/libexif/libexif/releases/download/v${EXIF_VER}/libexif-${EXIF_VER}.tar.bz2")
  src=$(unpack "$tb" "libexif-${EXIF_VER}")
  bld="$BUILDDIR/exif"; rm -rf "$bld"; mkdir -p "$bld"
  ( cd "$bld" && run exif-conf "$src/configure" "${conf_common[@]}" \
      --disable-nls --disable-docs )
  ( cd "$bld" && run exif-make make -j"$JOBS" )
  ( cd "$bld" && run exif-inst make install )
  stamp exif
}

# ----------------------------------------------------------------- iptc -----
# The upstream SourceForge tarball path 404s; GitHub is the live mirror and its
# tags spell the version with underscores (release_1_0_5), hence the double
# substitution.
stage_iptc() {
  need_stage iptc || return 0
  local tb src bld
  tb=$(fetch "https://github.com/ianw/libiptcdata/releases/download/release_${IPTC_VER//./_}/libiptcdata-${IPTC_VER}.tar.gz")
  src=$(unpack "$tb" "libiptcdata-${IPTC_VER}")
  bld="$BUILDDIR/iptc"; rm -rf "$bld"; mkdir -p "$bld"
  ( cd "$bld" && run iptc-conf "$src/configure" "${conf_common[@]}" \
      --disable-nls --without-python )
  ( cd "$bld" && run iptc-make make -j"$JOBS" )
  ( cd "$bld" && run iptc-inst make install )
  stamp iptc
}

# ----------------------------------------------------------------- vips -----
stage_vips() {
  need_stage vips || return 0
  local tb src bld
  tb=$(fetch "https://github.com/libvips/libvips/releases/download/v${VIPS_VER}/vips-${VIPS_VER}.tar.xz")
  src=$(unpack "$tb" "vips-${VIPS_VER}")

  # Mandatory pre-setup patch. The Static Linux SDK's musl libc.a bundles
  # mimalloc, which exports the MSVC-compatibility symbol _aligned_malloc.
  # libvips probes for it with meson's cc.has_function(), which is a *link*
  # test -- so it succeeds, HAVE__ALIGNED_MALLOC gets defined, and
  # composite.cpp takes the Windows branch calling _aligned_malloc/
  # _aligned_free, which no header on this platform declares. Hard compile
  # failure. Drop the probe and leave posix_memalign/memalign, which is what
  # every other Linux build picks anyway.
  sed -i "s/^func_names = .*/func_names = [ 'posix_memalign', 'memalign' ]/" "$src/meson.build"

  bld="$BUILDDIR/vips"; rm -rf "$bld"; mkdir -p "$bld"

  # -Dmodules=disabled is mandatory, not tidiness. Under static musl, dlopen()
  # is a stub that always fails, yet g_module_supported() still returns 1 --
  # so a modular build links, starts, and then finds no image loader at all at
  # runtime. Everything must be compiled in.
  #
  # -Dauto_features=disabled means the enabled list below is exhaustive: JPEG,
  # PNG (via spng), WebP, TIFF, EXIF, zlib. HEIC is deliberately absent -- it
  # would drag libheif plus a C++ AV1/HEVC decoder into the closure.
  run vips-setup meson setup "$bld" "$src" --cross-file "$CROSSFILE" \
      --prefix="$PREFIX" --libdir=lib --default-library=static --prefer-static \
      --buildtype=release -Dwrap_mode=nodownload \
      -Dauto_features=disabled -Ddeprecated=false -Dexamples=false \
      -Dcplusplus=false -Dmodules=disabled -Dintrospection=disabled \
      -Ddoxygen=false -Dgtk_doc=false \
      -Djpeg=enabled -Dexif=enabled -Dzlib=enabled \
      -Dspng=enabled -Dwebp=enabled -Dtiff=enabled
  run vips-build meson compile -C "$bld" -j "$JOBS"
  run vips-inst meson install -C "$bld" --no-rebuild
  stamp vips
}

# ------------------------------------------------------------- flat .pc -----
# Overwrite meson's generated vips.pc with a flattened one. This is not
# cosmetic; SwiftPM has its own .pc parser (it does not shell out to
# pkg-config) with three behaviours that each break a static cross build:
#
#   1. It drops `Libs.private:` entirely -- so anything vips only records there
#      never reaches the link line.
#   2. It expands `Requires:` in *declaration* order. meson writes
#      `Requires: glib-2.0, gio-2.0, gobject-2.0, ...`, i.e. glib before its
#      dependents, which is exactly backwards for a single-pass static link.
#   3. If any single `Requires`/`Requires.private` entry cannot be resolved it
#      silently discards ALL cflags from that .pc, so the build fails on a
#      missing vips/vips.h rather than on the actual cause.
#
# So: no Requires at all, and one hand-ordered Libs line -- dependents before
# dependencies, left to right.
#
#   vips
#     -> spng webp{mux,demux} tiff jpeg exif iptcdata expat   (format layer)
#     -> webp -> sharpyuv                (sharpyuv must follow libwebp)
#     -> tiff -> jpeg, z                 (jpeg must follow libtiff)
#     -> gio -> gobject -> gmodule -> glib -> ffi, pcre2-8    (glib stack)
#     -> z m                             (from the SDK sysroot)
#
# -lgmodule-2.0 stays even though vips modules are disabled: libgio-2.0.a
# genuinely has undefined g_module_* references.
#
# SwiftExif reads libexif.pc and libiptcdata.pc from this same prefix
# unmodified -- both are already flat and need no rewriting.
write_flat_vips_pc() {
  local pc="$PREFIX/lib/pkgconfig/vips.pc"
  cat > "$pc" <<PC
prefix=${PREFIX}
includedir=\${prefix}/include
libdir=\${prefix}/lib

Name: vips
Description: Image processing library (flattened for SwiftPM's .pc parser)
Version: ${VIPS_VER}
Requires:
Libs: -L\${libdir} -lvips -lspng -lwebpmux -lwebpdemux -lwebp -lsharpyuv -ltiff -ljpeg -lexif -liptcdata -lexpat -lgio-2.0 -lgobject-2.0 -lgmodule-2.0 -lglib-2.0 -lffi -lpcre2-8 -lz -lm
Cflags: -I\${includedir} -I\${includedir}/glib-2.0 -I\${libdir}/glib-2.0/include
PC
  echo "== wrote flattened $pc"
}

# ------------------------------------------------------------------ main ----
ALL_STAGES=(khdrs libffi pcre2 glib expat jpeg spng webp tiff exif iptc vips)

STAGES=("$@")
if [ "${#STAGES[@]}" -eq 0 ]; then
  STAGES=("${ALL_STAGES[@]}")
fi

for s in "${STAGES[@]}"; do
  echo "===================== stage: $s ($ARCH) ====================="
  "stage_$s"
done

# Always rewrite the flattened .pc: it is cheap, and a partial re-run that
# reinstalls vips would otherwise leave meson's version in place.
write_flat_vips_pc

echo "== done. prefix: $PREFIX"
ls "$PREFIX/lib"/*.a 2>/dev/null || true
