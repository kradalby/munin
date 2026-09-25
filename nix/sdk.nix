# The Static Linux SDK artifactbundle.
#
# `swift sdk install` only untars and checks a hash, and fetchurl does the
# hash, so this is the untar; --swift-sdks-path reads it in place. Also
# sidesteps SDK installs being per-$HOME.
#
# Ships musl sysroots for both triples, but no XCTest or swift-testing --
# hence no unit tests against musl.
{
  pkgs,
  version ? "6.4.0",
}: let
  name = "swift-${version}-RELEASE_static-linux-0.1.0";
in
  pkgs.stdenvNoCC.mkDerivation {
    pname = "swift-static-linux-sdk";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://download.swift.org/swift-${version}-release/static-sdk/swift-${version}-RELEASE/${name}.artifactbundle.tar.gz";
      # From the swift.org website data file, same value the Dockerfile pins:
      #   swift_releases.yml -> platform: static-sdk
      hash = "sha256-R9L9ie6/35601Ta2cQQUKX91XBeSbN68R0LAiYK0Cp4=";
    };

    dontUnpack = true;
    dontBuild = true;
    dontFixup = true; # target sysroot: nothing here executes on the host

    # configuration/ holds per-user overrides. SwiftPM creates it on every
    # --swift-sdks-path read and warns when it cannot; empty means none.
    installPhase = ''
      mkdir -p $out/configuration
      tar -xf $src -C $out
    '';
  }
