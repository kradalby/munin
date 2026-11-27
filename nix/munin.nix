# The dynamic build: what `swift build` makes, on Linux and Darwin alike.
#
# passthru.tests.unit is `swift test`. The static build cannot run it (the
# Static SDK ships no test framework), so this is the only place it runs.
{
  pkgs,
  src,
  swiftpmDeps,
  # src plus example/, which the tests read; kept out of the package so an
  # example/ edit does not rebuild it.
  testSrc,
}: let
  inherit (pkgs) lib;

  munin = pkgs.swiftPackages.stdenv.mkDerivation {
    pname = "munin";
    version = "0";
    inherit src swiftpmDeps;

    nativeBuildInputs = with pkgs; [swift swiftpm pkg-config];

    buildInputs = with pkgs;
      [
        # SwiftExif
        libexif
        libiptcdata

        vips.dev

        # Everything vips.pc and glib.pc name under Requires.private.
        # pkg-config walks those only for --static; SwiftPM's own parser
        # walks them always, and drops *all* cflags when one is missing.
        #
        # If compiling against libvips fails with
        #   fatal error: 'glib.h' file not found
        # look for a warning just before it, such as
        #   warning: couldn't find pc file for spng
        # and add that package here.
        cfitsio
        cgif
        dav1d.dev
        expat.dev
        fftw.dev
        fribidi
        glib.dev
        hdf5.dev
        lcms2.dev
        libarchive.dev
        libdatrie.dev
        libgsf.dev
        libhwy
        libimagequant
        libraw.dev
        librsvg.dev
        libspng.dev
        libthai
        libultrahdr.dev
        libwebp
        libxdmcp.dev
        matio
        openexr.dev
        openjpeg.dev
        openssl.dev
        orc.dev
        pango.dev
        pcre2.dev

        # glib.pc -> sysprof-capture-4, which nixpkgs has on Linux only.
        # Nothing links it, so an empty .pc suffices.
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
      ]
      ++ lib.optionals stdenv.hostPlatform.isLinux [
        libselinux.dev
        libsepol.dev
        util-linux.dev
      ];

    # swift-build, the default since 6.4, segfaults while planning on CI
    # runners (passes locally); native is what this package always used.
    swiftpmFlags = ["--build-system" "native"];

    passthru.tests.unit = munin.overrideAttrs {
      pname = "munin-unit-tests";
      src = testSrc;
      doCheck = true;
      # nixpkgs' Foundation reads it; the sandbox has no /usr/share/zoneinfo.
      TZDIR = "${pkgs.tzdata}/share/zoneinfo";
      installPhase = "touch $out";
    };

    meta.mainProgram = "munin";
  };
in
  munin
