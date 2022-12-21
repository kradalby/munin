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
        munin = pkgs.stdenv.mkDerivation rec {
          name = "munin";
          src = ./.;

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

          buildPhase = let
            # On macOS, we have to use the Xcode bundled Swift
            swiftBin =
              if pkgs.stdenv.isLinux
              then "${pkgs.swift}/bin/swift"
              else "/usr/bin/swift";

            extraArgs = [] ++ (pkgs.lib.optionals pkgs.stdenv.isDarwin ["--disable-sandbox"]);
          in ''
            # ${swiftBin} package resolve
            ${swiftBin} build -v --configuration release --skip-update ${builtins.concatStringsSep " " extraArgs}
          '';

          installPhase = ''
            mkdir -p $out/bin
            cp ./.build/release/${name} $out/bin/${name}
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
