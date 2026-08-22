# The swift.org toolchain, patchelfed onto nixpkgs.
#
# Not nixpkgs' swift: that is too old to parse this package's manifest. This
# is the same Ubuntu tarball CI and the Docker image use.
#
# Untars into $out rather than the build dir: it is large unpacked, and the
# daemon's build dir is often a tmpfs.
{
  pkgs,
  version ? "6.3.1",
}: let
  inherit (pkgs) stdenv;

  # What a host (glibc) compile needs to see as <sysroot>/usr/include.
  hostInclude = pkgs.buildEnv {
    name = "swift-host-include";
    paths = [pkgs.glibc.dev pkgs.linuxHeaders];
  };
in
  stdenv.mkDerivation {
    pname = "swift-bin";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://download.swift.org/swift-${version}-release/ubuntu2404/swift-${version}-RELEASE/swift-${version}-RELEASE-ubuntu24.04.tar.gz";
      hash = "sha256-x5KKv9prkW2BLSMaXHJKamvfJYeCmPa97ORR9YWrml8=";
    };

    nativeBuildInputs = [pkgs.autoPatchelfHook];

    buildInputs = with pkgs; [
      stdenv.cc.cc.lib # libstdc++
      zlib
      # swift-build links an older libxml2 soname than nixpkgs now ships;
      # libxml2_13 still provides it.
      libxml2_13
      curl
      ncurses
      sqlite
      libuuid
      openssl
    ];

    # lldb-only sonames nixpkgs has moved past; nothing on the path from
    # `swift build` to a binary.
    autoPatchelfIgnoreMissingDeps = [
      "libedit.so.2"
      "libpython3.12.so.1.0"
    ];

    dontUnpack = true;
    dontBuild = true;
    dontStrip = true;

    installPhase = ''
      mkdir -p $out
      tar -xf $src -C $out --strip-components=2
      chmod -R u+w $out

      # 1. clang.cfg -- for the C driver.
      #
      # The toolchain already ships <triple>-clang.cfg for the two musl
      # targets, and clang loads exactly one config file: the triple-specific
      # one when it matches, otherwise plain clang.cfg. So a host-only config
      # lands here with no risk of leaking glibc paths into a --swift-sdk
      # cross link.
      #
      # Needed because SwiftPM compiles, links *and runs* Package.swift as a
      # host binary, and this clang knows nothing about where nix keeps
      # crt1.o, libgcc_s, or a dynamic loader that is not a stub.
      cat > $out/bin/clang.cfg <<EOF
      -idirafter ${hostInclude}/include
      -B${pkgs.glibc}/lib
      -L${pkgs.glibc}/lib
      -L${pkgs.gcc-unwrapped.lib}/lib
      --gcc-toolchain=${pkgs.gcc-unwrapped}
      -fuse-ld=lld
      -Wl,--dynamic-linker=${pkgs.glibc}/lib/ld-linux-x86-64.so.2
      -Wl,-rpath,${pkgs.glibc}/lib
      -Wl,-rpath,${pkgs.gcc-unwrapped.lib}/lib
      EOF
      ln -s clang.cfg $out/bin/clang++.cfg

      # swift-frontend embeds clang and never reads the driver config.
      # Without SDKROOT: "missing required module 'SwiftGlibc'", then a
      # missing swiftrt.o.
      mkdir -p $out/nix-sysroot/usr/lib
      ln -s ${hostInclude}/include $out/nix-sysroot/usr/include
      ln -s $out/lib/swift $out/nix-sysroot/usr/lib/swift
      ln -s $out/lib/swift_static $out/nix-sysroot/usr/lib/swift_static

      mkdir -p $out/nix-support
      echo "export SDKROOT=$out/nix-sysroot" > $out/nix-support/setup-hook
    '';

    meta.platforms = ["x86_64-linux"];
  }
