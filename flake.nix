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
  in
    {
      overlay = final: prev: let
        pkgs = nixpkgs.legacyPackages.${prev.system};
      in rec {
        munin = let
          src = builtins.filterSource (path: type:
            !(builtins.elem (baseNameOf path) [
              "flake.nix"
              "flake.lock"
              ".git"
              ".build"
              ".direnv"
            ]))
          ./.;

          # On macOS, we have to use the Xcode bundled Swift
          swiftBin =
            if pkgs.stdenv.isLinux
            then "${pkgs.swift}/bin/swift"
            else "/usr/bin/swift";
        in
          pkgs.stdenv.mkDerivation rec {
            name = "munin";
            inherit src;

            postUnpack = ''
              export HOME="$TMP"
            '';

            nativeBuildInputs = [pkgs.pkg-config];
            buildInputs = with pkgs;
              [
                git
                cacert
                clang
                coreutils
                imagemagick6
                libexif
                libiptcdata
              ]
              ++ lib.optionals pkgs.stdenv.isLinux [
                swift
                swift-corelibs-libdispatch
              ];

            # TODO: figure out why this isnt working
            sandboxProfile =
              if pkgs.stdenv.isDarwin
              then ''
                (allow file-read* file-write* process-exec mach-lookup)
                ; block homebrew dependencies
                (deny file-read* file-write* process-exec mach-lookup (subpath "/usr/local") (with no-log))
              ''
              else "";

            buildPhase = let
              extraArgs = [] ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin ["--disable-sandbox"]);
              # extraArgs = [];
            in ''
              ${swiftBin} build -v \
                --configuration release \
                --skip-update \
                ${builtins.concatStringsSep " " extraArgs} \
                -Xswiftc -I${pkgs.imagemagick6}/include/ImageMagick-6 \
                -Xlinker -L${pkgs.imagemagick6}/lib
            '';

            installPhase = ''
              install -D -m 0555 .build/release/munin $out/bin/munin
            '';

            # TODO: Checks with swift test

            outputHashAlgo = "sha256";
            outputHashMode = "recursive";
            outputHash =
              if pkgs.stdenv.isDarwin
              then "sha256-hYObgh9VNchryqp6HKjl2T6Hh0M5uSCMBh524vENnBI="
              else "";
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
        nativeBuildInputs = [pkgs.pkg-config];
        buildInputs = with pkgs;
          [
            clang
            coreutils
            imagemagick6
            libexif
            libiptcdata
          ]
          ++ lib.optionals pkgs.stdenv.isLinux [
            swift
            swift-corelibs-libdispatch
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
