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
          # On macOS, we have to use the Xcode bundled Swift
          swiftBin =
            if pkgs.stdenv.isLinux
            then "${pkgs.swift}/bin/swift"
            else "/usr/bin/swift";
        in
          pkgs.stdenv.mkDerivation rec {
            name = "munin";
            src = ./.;

            postUnpack = ''
              export HOME="$TMP"
            '';

            nativeBuildInputs = [pkgs.pkg-config];
            buildInputs = with pkgs;
              [
                git
                clang
                coreutils
                imagemagick6
                libexif
                libiptcdata
                # deps
              ]
              ++ lib.optionals pkgs.stdenv.isLinux [
                swift
                swift-corelibs-libdispatch
              ];

            sandboxProfile =
              if pkgs.stdenv.isDarwin
              then ''
                (allow file-read* file-write* process-exec mach-lookup)
                ; block homebrew dependencies
                (deny file-read* file-write* process-exec mach-lookup (subpath "/usr/local") (with no-log))
              ''
              else "";

            buildPhase = let
              # extraArgs = [] ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin ["--disable-sandbox"]);
              extraArgs = [];
            in ''
              # ${swiftBin} package -v resolve ${builtins.concatStringsSep " " extraArgs}
              ${swiftBin} build -v --configuration release --skip-update ${builtins.concatStringsSep " " extraArgs}
            '';

            installPhase = ''
              install -D -m 0555 build/release/munin $out/bin/munin
            '';

            outputHashAlgo = "sha256";
            outputHashMode = "recursive";
            outputHash = "";
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

      # `nix build`
      packages = with pkgs; {
        inherit munin;
      };
      defaultPackage = pkgs.munin;
    });
}
