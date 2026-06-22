{
  # Development-environment-only flake.
  #
  # This flake provides the C library dependencies Munin needs (libvips,
  # libexif, libiptcdata, libgd, glib, pkg-config, plus the transitive
  # swift-vips pile) and related development tooling (swift-format,
  # sourcekit-lsp).
  #
  # The Swift toolchain is **deliberately not provided** by this flake. The
  # Swift packages in nixpkgs lag the official Swift.org releases and mix
  # oddly with the C-library stdenv, so we keep Swift out of scope here and
  # rely on the developer to install a matching toolchain themselves. See
  # README.md for installation instructions (swiftly or the Swift.org
  # tarball; the CI workflow pins Swift 6.3.1).
  #
  # The `nix build` target has been dropped along with Swift — it depended
  # on `swiftpm2nix` and the in-nix Swift packages. Releases come from
  # `swift build -c release` run against this devShell.

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
    # Native build-tool dependencies: just pkg-config, for discovering the C
    # libraries below. Swift is intentionally not in this list.
    ndeps = pkgs:
      with pkgs; [
        pkg-config
      ];

    # C library dependencies linked against by SwiftExif, swift-vips, and
    # Munin itself. Everything here must be present at compile *and* run
    # time (they're shared libraries, not headers-only).
    bdeps = pkgs:
      with pkgs;
        [
          # SwiftExif
          libexif
          libiptcdata

          # swift-vips: image processing + transitive pile
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

          libarchive.dev
          cgif
          libspng.dev
          xorg.libXdmcp.dev
          libhwy

          openssl.dev

          # If compiling swift-vips fails with something like:
          #   fatal error: 'glib.h' file not found
          # look for a warning just before it:
          #   warning: couldn't find pc file for spng
          # and add the corresponding nixpkgs package here.
        ]
        ++ lib.optionals stdenv.isLinux [
          # swift-vips Linux-only C deps
          glibc.dev
          libselinux.dev
          libsepol.dev
          pcre.dev
          util-linux.dev
        ];
  in
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {inherit system;};

      # Shell hook that nudges the user towards installing Swift if it is
      # missing. We don't provide it from nixpkgs (see the file header for
      # why), but without Swift on PATH the devShell is not much use.
      swiftCheckHook = ''
        if ! command -v swift >/dev/null 2>&1; then
          echo
          echo "  ⚠  swift not found on PATH."
          echo "     Install the Swift 6.3.1 toolchain (matching CI) via either:"
          echo "       • swiftly:  https://www.swift.org/install/"
          echo "       • tarball:  https://download.swift.org/"
          echo
        else
          echo "  swift found: $(command -v swift)"
          swift --version 2>/dev/null | head -n 1 | sed 's/^/  /'
        fi
      '';
    in {
      devShells.default = pkgs.mkShell {
        nativeBuildInputs = ndeps pkgs;
        buildInputs =
          (bdeps pkgs)
          ++ [
            pkgs.swift-format
            pkgs.swiftlint
            pkgs.sourcekit-lsp
          ];
        shellHook = swiftCheckHook;
      };
    });
}
