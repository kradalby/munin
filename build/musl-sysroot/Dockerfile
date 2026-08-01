# Cross-build environment for Munin's C dependency closure.
#
# One x86_64 container produces static musl archives for BOTH
# x86_64-swift-linux-musl and aarch64-swift-linux-musl, using the Swift
# toolchain's own clang aimed at the Static Linux SDK sysroots. There is no
# Alpine base, no arm64 runner and no qemu in the build path -- qemu-user is
# installed only so meson can run the handful of compile-and-run probes that
# aarch64 builds need.
#
# Build:  docker build -t munin-musl build/musl-sysroot
# Use:    `make build-musl-sysroot` at the repo root, or see build.sh's header.

FROM swift:6.3.1

ARG DEBIAN_FRONTEND=noninteractive

# nasm is load-bearing, not incidental: libjpeg-turbo's CMake silently falls
# back to WITH_SIMD=0 on x86_64 when it cannot find an assembler, which costs
# roughly 2-4x on JPEG decode/encode -- exactly Munin's hot path. aarch64 SIMD
# is intrinsics-based and needs no assembler.
# No autoconf/automake/libtool/gettext/texinfo: every autotools stage runs the
# `configure` its tarball ships, never autoreconf, and all of them are built
# --disable-nls. No git or patch either: the one source edit is a sed, and
# meson runs with -Dwrap_mode=nodownload so it never fetches a subproject.
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential ninja-build python3 python3-pip python3-venv \
      pkg-config cmake curl ca-certificates \
      xz-utils bzip2 file nasm \
      qemu-user-static \
    && rm -rf /var/lib/apt/lists/*

# Ubuntu 24.04 ships meson 1.3.2; glib 2.86 and libvips 8.16 both want newer.
RUN pip3 install --break-system-packages --no-cache-dir 'meson==1.9.1'

# The Static Linux SDK carries the musl sysroots (headers, libc.a, compiler-rt,
# libc++.a) for both target arches. Pinned by checksum so a silent upstream
# republish cannot change what we link against.
ARG SDK_VERSION=swift-6.3.1-RELEASE_static-linux-0.1.0
ARG SDK_URL=https://download.swift.org/swift-6.3.1-release/static-sdk/swift-6.3.1-RELEASE/${SDK_VERSION}.artifactbundle.tar.gz
ARG SDK_CHECKSUM=fac05271c1f7d060bd203240ce5251d5ca902d30ac899f553765dbb3a88b97ad
RUN swift sdk install "${SDK_URL}" --checksum "${SDK_CHECKSUM}" \
    && swift sdk list

WORKDIR /work
