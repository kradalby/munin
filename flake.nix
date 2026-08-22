{
  # The static Linux binary only. See nix/README.md.
  #
  # The dynamic Linux and Darwin builds are not nix packages: nixpkgs' swift is
  # too old to parse this package's manifest, and on Darwin the toolchain lives
  # in Xcode, outside the store.
  #
  # No `swift test` check either — the Static SDK ships no test framework, so
  # the suite runs on the dynamic builds (.github/workflows/swift-ci.yml).

  inputs = {
    nixpkgs.url = "nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    inherit (nixpkgs) lib;

    # Not flake-utils' defaultSystems: those include x86_64-darwin, which
    # current nixpkgs throws on at `import`, so `--all-systems` exited 1.
    #
    # Branch on this string, never on pkgs.stdenv.isLinux -- the latter forces
    # pkgs, which is what throws.
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];

    forAllSystems = f: lib.genAttrs systems (system: f system);

    # Native build-tool dependencies: pkg-config, for discovering the C
    # libraries below. Swift is intentionally not in this list.
    ndeps = pkgs:
      with pkgs; [
        pkg-config
      ];

    # Shared libraries, so needed at run time as well as compile time.
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

          # Requires.private in vips.pc. pkg-config resolves those only for
          # --static; SwiftPM's own parser walks them always, and drops *all*
          # cflags when one is missing.
          dav1d.dev
          hdf5.dev
          libraw.dev
          libultrahdr.dev

          # Same, for glib.pc -> sysprof-capture-4, but sysprof is Linux-only
          # in nixpkgs. Nothing links it, so an empty .pc suffices.
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
  in {
    devShells = forAllSystems (system: let
      pkgs = import nixpkgs {inherit system;};

      # This shell does not provide Swift (see header); say so rather than
      # letting `swift build` fail with command-not-found.
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
      # Darwin's stdenv points SDKROOT/DEVELOPER_DIR at nixpkgs' apple-sdk,
      # which the system Swift refuses ("this SDK is not supported by the
      # compiler"). Hand them back to Xcode; pkg-config still points at nix.
      systemToolchainHook = pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
        unset SDKROOT DEVELOPER_DIR CC CXX
      '';
    in {
      # mkShellNoCC, not mkShell: a C compiler puts nix's gcc-wrapper `ld`
      # ahead of the Swift toolchain's own, and the compiled Package.swift then
      # dies on exec as "Missing or empty JSON output from manifest
      # compilation". pkg-config needs no wrapper.
      #
      # Consequence: nothing bakes an -rpath, so a Linux binary linked here
      # cannot find its C libraries at run time. LD_LIBRARY_PATH makes it worse —
      # it applies to every process in the shell, so the Swift toolchain picks
      # up nix's libcurl and `swift --version` segfaults. Compile and lint
      # here; run via `make docker-*`. macOS is unaffected (absolute install
      # names).
      default = pkgs.mkShellNoCC {
        nativeBuildInputs = ndeps pkgs;
        buildInputs =
          (bdeps pkgs)
          ++ [
            pkgs.swiftlint
          ];
        shellHook = systemToolchainHook + swiftCheckHook;
      };
    });
  };
}
