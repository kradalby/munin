{
  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  }: let
    version =
      if (self ? shortRev)
      then self.shortRev
      else "dev";

    ndeps = pkgs:
      with pkgs; [
        swift
        swiftPackages.swiftpm
        pkg-config
      ];

    bdeps = pkgs:
      with pkgs;
        [
          swiftPackages.swift-driver
          swiftPackages.stdenv
          swiftPackages.XCTest

          # git
          # cacert
          #
          # clang
          # coreutils

          # SwiftExif
          libexif
          libiptcdata

          # swift-vips deps
          cfitsio
          expat.dev
          fftw.dev
          fribidi
          glib
          lcms2.dev
          libdatrie.dev
          libgsf.dev
          libimagequant
          librsvg.dev
          libthai
          libwebp
          matio
          openexr.dev
          openjpeg.dev
          orc.dev
          pango.dev
          pcre2.dev
          vips.dev
        ]
        ++ lib.optionals pkgs.stdenv.isLinux [
          swiftPackages.Foundation
          swift-corelibs-libdispatch

          # swift-vips deps
          libselinux.dev
          libsepol.dev
          pcre.dev
          util-linux.dev
          xorg.libXdmcp.dev
        ];
  in
    {
      overlay = final: prev: let
        pkgs = nixpkgs.legacyPackages.${prev.system};
      in rec {
        munin = let
          generated = pkgs.swiftpm2nix.helpers ./nix;
          src = builtins.filterSource (path: type:
            !(builtins.elem (baseNameOf path) [
              "flake.nix"
              "flake.lock"
              ".git"
              ".build"
              ".direnv"
            ]))
          ./.;
        in
          pkgs.stdenv.mkDerivation rec {
            pname = "munin";
            version = "0.0.0";

            inherit src;

            # Including SwiftPM as a nativeBuildInput provides a buildPhase for you.
            # This by default performs a release build using SwiftPM, essentially:
            #   swift build -c release
            nativeBuildInputs = ndeps pkgs;
            buildInputs = bdeps pkgs;

            propagatedBuildInputs = with pkgs; [
              glib
            ];

            # The helper provides a configure snippet that will prepare all dependencies
            # in the correct place, where SwiftPM expects them.
            configurePhase = generated.configure;

            # swiftpmFlags = ["--target x86_64-pc-linux-gnu"];

            installPhase = ''
              # This is a special function that invokes swiftpm to find the location
              # of the binaries it produced.
              binPath="$(swiftpmBinPath)"
              # Now perform any installation steps.
              mkdir -p $out/bin
              cp $binPath/munin $out/bin/
            '';
          };
      };
    }
    // flake-utils.lib.eachDefaultSystem
    (system: let
      pkgs = import nixpkgs {
        overlays = [self.overlay];
        inherit system;
      };
    in rec {
      # `nix develop`
      devShell = pkgs.mkShell {
        nativeBuildInputs = ndeps pkgs;
        buildInputs =
          (bdeps pkgs)
          ++ [
            pkgs.swift-format
            pkgs.sourcekit-lsp
            pkgs.swiftpm2nix

            # pkgs.swiftPackages.xcbuild
          ];
      };

      apps = {
        inherit (pkgs) munin;
      };
      defaultApp = pkgs.munin;

      overlays.default = self.overlay;

      # `nix build`
      packages = with pkgs; {
        inherit munin;
      };
      defaultPackage = pkgs.munin;
    });
}
