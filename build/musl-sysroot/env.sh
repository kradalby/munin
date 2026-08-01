#!/usr/bin/env bash
# Shared environment for cross-compiling C libraries to static musl archives
# with the Swift toolchain's clang against the Static Linux SDK sysroot.
#
# Usage:  source env.sh <arch>          # arch = x86_64 | aarch64
#
# Everything it writes goes under $WORK (default /work), which is deliberately
# independent of where this script lives: the recipe is mounted read-only and
# the scratch/output tree is a separate writable mount. See build.sh's header.
#
# Exports: ARCH TRIPLE SYSROOT RESOURCE_DIR PREFIX TOOLBIN CROSSFILE
#          CC CXX AR RANLIB STRIP NM LD CFLAGS CXXFLAGS LDFLAGS
#          PKG_CONFIG PKG_CONFIG_LIBDIR
# Side effects: creates $TOOLBIN wrappers, $PREFIX, the meson cross file, and
#               a fixed-up copy of the SDK's own .pc files.
set -euo pipefail

ARCH="${1:?usage: source env.sh <x86_64|aarch64>}"
# `return || exit` in the default branch because this file is normally sourced
# -- where `exit` would kill the caller -- but has a shebang and is executable,
# so it can also be run directly. shellcheck models only the sourced half and
# calls the `exit` dead (SC2317); it is reachable in the other half.
# shellcheck disable=SC2317
case "$ARCH" in
  x86_64)  MESON_CPU_FAMILY=x86_64;  MESON_CPU=x86_64 ;;
  aarch64) MESON_CPU_FAMILY=aarch64; MESON_CPU=aarch64; QEMU=qemu-aarch64-static ;;
  *) echo "unsupported arch: $ARCH" >&2; return 1 2>/dev/null || exit 1 ;;
esac

WORK="${WORK:-/work}"

# Both the artifactbundle directory and the musl sysroot inside it spell out
# versions (swift-6.3.1-RELEASE_static-linux-0.1.0, musl-1.2.5.sdk) that the
# Dockerfile also carries. Glob rather than repeat them, and insist on exactly
# one match: a version bump then only has to happen in the Dockerfile, and a
# half-installed or doubly-installed SDK fails here with a readable message
# instead of somewhere deep in a cross compile.
one() { # description, glob... -> the single match
  local what="$1"; shift
  if [ "$#" -ne 1 ] || [ ! -e "$1" ]; then
    echo "env.sh: expected exactly one $what, found: $*" >&2
    return 1
  fi
  echo "$1"
}

SDK_BUNDLE="${SDK_BUNDLE:-$(one 'installed Static Linux SDK' \
  /root/.swiftpm/swift-sdks/*_static-linux-*.artifactbundle/*/swift-linux-musl)}"

export ARCH
export TRIPLE="${ARCH}-swift-linux-musl"
SYSROOT="$(one "musl sysroot for $ARCH in $SDK_BUNDLE" "$SDK_BUNDLE"/*.sdk/"$ARCH")"
export SYSROOT
# The host toolchain's own resource dir only ships x86_64 compiler-rt; the
# per-arch builtins live inside each sysroot. Point clang at those instead.
export RESOURCE_DIR="${SYSROOT}/usr/lib/swift/clang"
export PREFIX="${WORK}/out/${ARCH}"
export TOOLBIN="${WORK}/out/tools/${ARCH}"
export SRC="${WORK}/src"
export BUILDDIR="${WORK}/build/${ARCH}"
export LOGDIR="${WORK}/logs/${ARCH}"
export CROSSFILE="${WORK}/cross/${TRIPLE}.txt"

mkdir -p "$PREFIX/lib/pkgconfig" "$PREFIX/include" "$TOOLBIN" "$SRC" \
         "$BUILDDIR" "$LOGDIR" "$WORK/cross" "$WORK/dl"

# --gcc-toolchain is not optional. Without it clang's GCC-installation
# detection puts the *host* /usr/lib/gcc/x86_64-linux-gnu/13 on the library
# search path even though --sysroot points at the musl SDK, and meson's
# cc.find_library('atomic') then bakes the absolute path of a glibc
# /usr/lib/gcc/.../libatomic.a into glib-2.0.pc's Libs. Pointing it at the
# sysroot (which has no lib/gcc) makes the search path musl-only.
CLANG_BASE_FLAGS="--target=${TRIPLE} --sysroot=${SYSROOT} -resource-dir=${RESOURCE_DIR} --gcc-toolchain=${SYSROOT}"

# ---------------------------------------------------------------- wrappers --
# Real executables rather than shell functions so autotools, meson, cmake and
# libtool all see a plain compiler on PATH.
mk_wrapper() { # name, body
  local f="$TOOLBIN/$1"; shift
  printf '%s\n' '#!/bin/sh' "$@" > "$f"
  chmod +x "$f"
}

mk_wrapper "${TRIPLE}-clang" \
  "exec /usr/bin/clang ${CLANG_BASE_FLAGS} \"\$@\""
mk_wrapper "${TRIPLE}-clang++" \
  "exec /usr/bin/clang++ ${CLANG_BASE_FLAGS} \"\$@\""
# gcc/g++/cc aliases: some configure scripts and cmake probes look for them.
for alias in gcc g++ cc; do
  case "$alias" in
    g++) mk_wrapper "${TRIPLE}-${alias}" "exec ${TOOLBIN}/${TRIPLE}-clang++ \"\$@\"" ;;
    *)   mk_wrapper "${TRIPLE}-${alias}" "exec ${TOOLBIN}/${TRIPLE}-clang \"\$@\"" ;;
  esac
done
mk_wrapper "${TRIPLE}-ar"      'exec /usr/bin/llvm-ar "$@"'
mk_wrapper "${TRIPLE}-ranlib"  'exec /usr/bin/llvm-ranlib "$@"'
mk_wrapper "${TRIPLE}-nm"      'exec /usr/bin/llvm-nm "$@"'
mk_wrapper "${TRIPLE}-strip"   'exec /usr/bin/llvm-strip "$@"'
mk_wrapper "${TRIPLE}-objdump" 'exec /usr/bin/llvm-objdump "$@"'
mk_wrapper "${TRIPLE}-objcopy" 'exec /usr/bin/llvm-objcopy "$@"'
mk_wrapper "${TRIPLE}-ld"      'exec /usr/bin/ld.lld "$@"'

# ------------------------------------------------------------- pkg-config ---
# The .pc files shipped inside the SDK sysroot carry an absolute prefix from
# the machine that built the SDK (/home/build-user/build/sdk_root/<arch>/usr),
# which resolves to nothing here. Copy them into our staging prefix with the
# prefix rewritten, so zlib/libxml2/liblzma/libcurl from the SDK are usable.
for pc in "$SYSROOT"/usr/lib/pkgconfig/*.pc; do
  [ -e "$pc" ] || continue
  base=$(basename "$pc")
  [ -e "$PREFIX/lib/pkgconfig/$base" ] && continue
  sed -e "s|^prefix=.*|prefix=${SYSROOT}/usr|" \
      -e "s|/home/build-user/build/sdk_root/${ARCH}/usr|${SYSROOT}/usr|g" \
      "$pc" > "$PREFIX/lib/pkgconfig/$base"
done

mk_wrapper "${TRIPLE}-pkg-config" \
  "PKG_CONFIG_LIBDIR=${PREFIX}/lib/pkgconfig" \
  "export PKG_CONFIG_LIBDIR" \
  'exec /usr/bin/pkg-config --static "$@"'

# ----------------------------------------------------------------- exports --
export PATH="${TOOLBIN}:${PATH}"
export CC="${TRIPLE}-clang"
export CXX="${TRIPLE}-clang++"
export AR="${TRIPLE}-ar"
export RANLIB="${TRIPLE}-ranlib"
export NM="${TRIPLE}-nm"
export STRIP="${TRIPLE}-strip"
export LD="${TRIPLE}-ld"
export OBJDUMP="${TRIPLE}-objdump"
# -fPIC everywhere. The final Swift link is a plain static ET_EXEC, not
# static-pie (scripts/build-static.sh asserts no PT_INTERP and no DT_NEEDED),
# and that link takes PIC objects without complaint. Building PIC anyway costs
# nothing measurable here and keeps these archives usable if the link mode ever
# moves; the alternative, -fno-pic, is the one that would have to be revisited.
export CFLAGS="-O2 -fPIC -g0"
export CXXFLAGS="-O2 -fPIC -g0"
export CPPFLAGS="-I${PREFIX}/include"
export LDFLAGS="-static -L${PREFIX}/lib"
export PKG_CONFIG="${TRIPLE}-pkg-config"
export PKG_CONFIG_LIBDIR="${PREFIX}/lib/pkgconfig"
unset PKG_CONFIG_PATH PKG_CONFIG_SYSROOT_DIR || true

# ------------------------------------------------------------- cross file ---
if [ "$ARCH" = x86_64 ]; then
  # x86_64 static-musl binaries execute fine on this glibc x86_64 host.
  EXE_WRAPPER_LINE=""
  NEEDS_EXE_WRAPPER="false"
else
  EXE_WRAPPER_LINE="exe_wrapper = '${QEMU}'"
  NEEDS_EXE_WRAPPER="true"
fi

cat > "$CROSSFILE" <<EOF
# Generated by env.sh -- do not edit by hand.
[binaries]
c = '${TOOLBIN}/${TRIPLE}-clang'
cpp = '${TOOLBIN}/${TRIPLE}-clang++'
ar = '${TOOLBIN}/${TRIPLE}-ar'
ranlib = '${TOOLBIN}/${TRIPLE}-ranlib'
strip = '${TOOLBIN}/${TRIPLE}-strip'
nm = '${TOOLBIN}/${TRIPLE}-nm'
ld = '${TOOLBIN}/${TRIPLE}-ld'
pkg-config = '${TOOLBIN}/${TRIPLE}-pkg-config'
pkgconfig = '${TOOLBIN}/${TRIPLE}-pkg-config'
${EXE_WRAPPER_LINE}

[properties]
needs_exe_wrapper = ${NEEDS_EXE_WRAPPER}
pkg_config_libdir = '${PREFIX}/lib/pkgconfig'
# Deliberately NO sys_root here. Meson prepends it to every -I in c_args, which
# turns -I\$PREFIX/include into -I\$SYSROOT\$PREFIX/include; glib builds with
# -Werror=missing-include-dirs and dies on the bogus path. Our .pc files carry
# absolute host paths already, so pkg-config needs no sysroot rewriting.

[built-in options]
c_args = ['-O2', '-fPIC', '-g0', '-I${PREFIX}/include']
cpp_args = ['-O2', '-fPIC', '-g0', '-I${PREFIX}/include']
c_link_args = ['-static', '-L${PREFIX}/lib']
cpp_link_args = ['-static', '-L${PREFIX}/lib']
prefix = '${PREFIX}'
libdir = 'lib'
default_library = 'static'
prefer_static = true
b_staticpic = true

[host_machine]
system = 'linux'
kernel = 'linux'
subsystem = 'linux'
cpu_family = '${MESON_CPU_FAMILY}'
cpu = '${MESON_CPU}'
endian = 'little'
EOF

echo "== env ready: TRIPLE=$TRIPLE PREFIX=$PREFIX CROSSFILE=$CROSSFILE"
