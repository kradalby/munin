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
      with pkgs;
        [
          pkg-config
        ]
        ++ lib.optionals stdenv.isLinux [
          swiftPackages.swiftNoSwiftDriver
          swiftPackages.swiftpm
        ];

    bdeps = pkgs:
      with pkgs;
        [
          # SwiftExif
          libexif
          libiptcdata

          # swift-vips deps
          cfitsio
          expat.dev
          fftw.dev
          fribidi
          glib.dev
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

          # Added 2024-02-07
          libarchive.dev
          cgif
          libspng.dev
          xorg.libXdmcp.dev
          libhwy

          # Added 2024-06-04
          openssl.dev

          # If the compilation of swift-vips is failing with something like:
          # fatal error: 'glib.h' file not found
          # look for a warning before the error like:
          # warning: couldn't find pc file for spng
          # and find that library in Nix and add it to the buildDeps.
        ]
        ++ lib.optionals stdenv.isLinux [
          swiftPackages.stdenv
          swiftPackages.XCTest
          swiftPackages.Foundation
          swiftPackages.Dispatch

          swift-corelibs-libdispatch
          glibc.dev

          # swift-vips linux deps
          libselinux.dev
          libsepol.dev
          pcre.dev
          util-linux.dev
        ];
  in
    {
      overlay = _: prev: let
        pkgs = nixpkgs.legacyPackages.${prev.system};
      in {
        munin = let
          generated = pkgs.swiftpm2nix.helpers ./nix;
          src = builtins.filterSource (path: _:
            !(builtins.elem (baseNameOf path) [
              "flake.nix"
              "flake.lock"
              ".git"
              ".build"
              ".direnv"
            ]))
          ./.;
        in
          pkgs.swift.stdenv.mkDerivation {
            pname = "munin";
            inherit version;

            inherit src;
            LD_LIBRARY_PATH =
              if pkgs.stdenv.isLinux
              then "${pkgs.swiftPackages.Dispatch}/lib"
              else null;

            strictDeps = true;

            # Including SwiftPM as a nativeBuildInput provides a buildPhase for you.
            # This by default performs a release build using SwiftPM, essentially:
            #   swift build -c release
            nativeBuildInputs = ndeps pkgs;
            buildInputs = bdeps pkgs;

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
    in {
      # `nix develop`
      devShell = pkgs.mkShell.override {inherit (pkgs.swift) stdenv;} {
        LD_LIBRARY_PATH =
          if pkgs.stdenv.isLinux
          then "${pkgs.swiftPackages.Dispatch}/lib"
          else null;
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
