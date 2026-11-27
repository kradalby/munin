# The Static Linux SDK artifactbundle, made usable by nixpkgs' swift.
#
# `swift sdk install` only untars and checks a hash, and fetchurl does the
# hash, so this is the untar; --swift-sdks-path reads it in place. Also
# sidesteps SDK installs being per-$HOME.
#
# Ships musl sysroots for both triples, but no XCTest or swift-testing --
# hence no unit tests against musl.
{
  pkgs,
  version ? pkgs.swift.version,
}: let
  name = "swift-${version}-RELEASE_static-linux-0.1.0";
  llvm = pkgs.swiftPackages.llvmPackages;
in
  pkgs.stdenvNoCC.mkDerivation {
    pname = "swift-static-linux-sdk";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://download.swift.org/swift-${version}-release/static-sdk/swift-${version}-RELEASE/${name}.artifactbundle.tar.gz";
      # From the swift.org website data file:
      #   swift_releases.yml -> platform: static-sdk
      hash = "sha256-R9L9ie6/35601Ta2cQQUKX91XBeSbN68R0LAiYK0Cp4=";
    };

    dontUnpack = true;
    dontBuild = true;
    dontFixup = true; # target sysroot: nothing here executes on the host

    installPhase = ''
      # configuration/ holds per-user overrides. SwiftPM creates it on every
      # --swift-sdks-path read and warns when it cannot; empty means none.
      mkdir -p $out/configuration
      tar -xf $src -C $out
      musl=$out/${name}.artifactbundle/${name}/swift-linux-musl

      # toolset.json's rootPath, empty upstream so the swift.org toolchain's
      # own clang is used. nixpkgs' clang is a cc-wrapper that forces host
      # glibc crt1.o and GNU ld into the link, so give the SDK an unwrapped
      # clang with the flags swift.org's <triple>-clang.cfg would add.
      bin=$musl/swift.xctoolchain/usr/bin
      for t in clang clang++; do
        cat > $bin/$t <<EOF
      #!${pkgs.runtimeShell}
      exec ${llvm.clang-unwrapped}/bin/$t -rtlib=compiler-rt -stdlib=libc++ \
        -fuse-ld=lld -unwindlib=libunwind -lc++abi -static \
        -Wno-unused-command-line-argument "\$@"
      EOF
        chmod +x $bin/$t
      done
      ln -s ${llvm.lld}/bin/ld.lld $bin/ld.lld

      # nixpkgs' ClangImporter adds host glibc headers -idirafter whenever
      # arch and OS match the host, ignoring the libc -- so x86_64 musl gets
      # them and aarch64 does not. musl has no sys/cdefs.h, which libdispatch
      # probes with __has_include and then finds glibc's. Empty is what
      # musl's absence means.
      for a in x86_64 aarch64; do
        : > $musl/musl-1.2.5.sdk/$a/usr/include/sys/cdefs.h
      done
    '';
  }
