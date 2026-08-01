{
  # Development-environment-only flake.
  #
  # This flake provides the C library dependencies Munin needs (libvips,
  # libexif, libiptcdata, glib, pkg-config, plus libvips' transitive pile)
  # and swiftlint (a prebuilt binary in nixpkgs).
  #
  # The Swift toolchain is **deliberately not provided** by this flake. The
  # Swift packages in nixpkgs lag the official Swift.org releases and mix
  # oddly with the C-library stdenv, so we keep Swift out of scope here and
  # rely on the developer to install a matching toolchain themselves. See
  # README.md for installation instructions (swiftly or the Swift.org
  # tarball; the CI workflow pins Swift 6.3.1). That toolchain already
  # bundles sourcekit-lsp and swift-format, so they are not provided here
  # either — the nixpkgs copies are 5.10-era and drag in the (broken on
  # Linux) nixpkgs Swift bootstrap.
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

    # C library dependencies linked against by SwiftExif and by Munin's own
    # Cvips / MuninVipsShim targets. Everything here must be present at
    # compile *and* run time (they're shared libraries, not headers-only).
    bdeps = pkgs:
      with pkgs;
        [
          # SwiftExif
          libexif
          libiptcdata

          # libvips: image processing + transitive pile
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
          libxdmcp.dev
          libhwy

          openssl.dev

          # vips.pc lists these under Requires.private. Real pkg-config only
          # resolves those for --static, but SwiftPM's own .pc parser walks
          # them unconditionally and drops *all* cflags when one is missing.
          dav1d.dev
          hdf5.dev
          libraw.dev
          libultrahdr.dev

          # Same story for glib.pc -> sysprof-capture-4, except sysprof is
          # Linux-only in nixpkgs. Nothing actually links it here, so an empty
          # .pc is enough to keep SwiftPM's resolver happy.
          # ponytail: stub, replace with pkgs.sysprof if a real link is ever needed.
          (writeTextFile {
            name = "sysprof-capture-4-stub";
            destination = "/lib/pkgconfig/sysprof-capture-4.pc";
            text = ''
              Name: sysprof-capture-4
              Description: stub for SwiftPM's Requires.private resolution
              Version: 3.38.0
              Cflags:
              Libs:
            '';
          })

          # If compiling against libvips fails with something like:
          #   fatal error: 'glib.h' file not found
          # look for a warning just before it:
          #   warning: couldn't find pc file for spng
          # and add the corresponding nixpkgs package here.
        ]
        ++ lib.optionals stdenv.isLinux [
          # libvips Linux-only C deps
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
      # On Darwin the stdenv exports SDKROOT/DEVELOPER_DIR pointing at nixpkgs'
      # apple-sdk (built with Swift 5.10) and CC/CXX pointing at the nix
      # cc-wrapper. The system Swift toolchain refuses that SDK ("this SDK is
      # not supported by the compiler") and the wrapper mis-handles SwiftPM's
      # --target. Hand those back to Xcode; pkg-config still points at nix.
      systemToolchainHook = pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
        unset SDKROOT DEVELOPER_DIR CC CXX
      '';
    in {
      # mkShellNoCC, not mkShell: a C compiler in the shell puts nix's
      # gcc-wrapper `ld` ahead of the Swift toolchain's own. SwiftPM then links
      # the compiled Package.swift against nix's dynamic linker while the Swift
      # runtime expects the system one, and the manifest binary dies on exec —
      # surfacing only as "Missing or empty JSON output from manifest
      # compilation". The C libraries below reach the build through
      # PKG_CONFIG_PATH, which needs no compiler wrapper.
      #
      # Consequence, and do not try to "fix" it with LD_LIBRARY_PATH: nothing
      # here bakes an -rpath either, so a Linux binary SwiftPM links in this
      # shell cannot find libvips.so.42 at run time. `swift build` succeeds and
      # the binary dies on exec. Putting the nix lib dirs on LD_LIBRARY_PATH
      # makes it worse, because that applies to *every* process in the shell:
      # the Swift.org toolchain is built against the system glibc, picks up
      # nix's libcurl and libxml2 instead, and `swift --version` segfaults.
      # This shell is for compiling, linting and cross-building; running Linux
      # binaries needs distro libraries (see the apt line in README.md), which
      # is what swift-ci.yml's Linux job uses. macOS is unaffected — nix dylibs
      # carry absolute install names, so dyld needs no search path.
      devShells.default = pkgs.mkShellNoCC {
        nativeBuildInputs = ndeps pkgs;
        buildInputs =
          (bdeps pkgs)
          ++ [
            pkgs.swiftlint
          ];
        shellHook = systemToolchainHook + swiftCheckHook;
      };
    });
}
