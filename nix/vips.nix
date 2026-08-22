# A trimmed static-musl libvips.
#
# nixpkgs' vips hardcodes every optional dependency into buildInputs, so
# keeping the closure narrow means replacing the input lists wholesale.
#
# That is also what keeps it evaluable: it drops gobject-introspection, whose
# postCheck reads hostPlatform.extensions.sharedLibrary, which static
# platforms do not define. Same for poppler -> nss via propagatedBuildInputs.
#
# This shadows a nixpkgs package and will drift. checks.smoke-amd64 is the
# early signal, on the commit that bumps flake.lock.
{
  pkgs,
  arch ? "x86_64",
}: let
  crossPkgs = import ./cross-pkgs.nix {inherit pkgs arch;};

  inherit (pkgs) lib;
in
  (crossPkgs.vips.override {
    withIntrospection = false;
    withDevDoc = false;
  })
  .overrideAttrs (old: {
    nativeBuildInputs = with pkgs; [
      meson
      ninja
      pkg-config
      glib # host glib, for glib-mkenums
      python3
    ];

    buildInputs = with crossPkgs; [
      glib
      expat
      libxml2
      libjpeg_turbo
      libpng
      libtiff
      # libtiff-4.pc Requires.private, all resolved by a static link.
      zstd
      xz
      libdeflate
      libwebp
      libexif
      cgif
      libhwy

      # glib's closure: a static link resolves every symbol in gio, including
      # libblkid and libmount, so propagation is not enough.
      pcre2
      libffi
      zlib
      gettext
      util-linux
      libselinux
      libsepol
      libsysprof-capture
    ];

    # vips.pc Requires. nixpkgs also propagates poppler, dragging in nss,
    # which does not evaluate under pkgsStatic either.
    propagatedBuildInputs = [crossPkgs.glib];

    # vips' own option names, not nixpkgs'. Enabled: JPEG, PNG, TIFF, WebP,
    # GIF out, EXIF. No HEIC/AVIF, JXL, PDF or ImageMagick. checks.smoke-*
    # decodes one file per enabled format, which stops this list narrowing.
    mesonFlags = [
      (lib.mesonEnable "introspection" false)
      (lib.mesonEnable "modules" false)
      (lib.mesonEnable "archive" false)
      (lib.mesonEnable "cfitsio" false)
      (lib.mesonEnable "fftw" false)
      (lib.mesonEnable "fontconfig" false)
      (lib.mesonEnable "heif" false)
      (lib.mesonEnable "imagequant" false)
      (lib.mesonEnable "jpeg-xl" false)
      (lib.mesonEnable "lcms" false)
      (lib.mesonEnable "magick" false)
      (lib.mesonEnable "matio" false)
      (lib.mesonEnable "nifti" false)
      (lib.mesonEnable "openexr" false)
      (lib.mesonEnable "openjpeg" false)
      (lib.mesonEnable "openslide" false)
      (lib.mesonEnable "orc" false)
      (lib.mesonEnable "pangocairo" false)
      (lib.mesonEnable "pdfium" false)
      (lib.mesonEnable "poppler" false)
      (lib.mesonEnable "quantizr" false)
      (lib.mesonEnable "raw" false)
      (lib.mesonEnable "rsvg" false)
      (lib.mesonEnable "spng" false) # nixpkgs uses libpng instead
      (lib.mesonEnable "uhdr" false)
      (lib.mesonBool "vapi" false)
      (lib.mesonBool "cplusplus" false)
      (lib.mesonBool "docs" false)
      (lib.mesonBool "examples" false)
      (lib.mesonOption "default_library" "static")
      # Without this meson omits --static, Libs.private never reaches the link
      # line, and vips' tools die on undefined ZSTD_* and blkid_*.
      (lib.mesonBool "prefer_static" true)
    ];

    doCheck = false;
    outputs = ["out"];
    postFixup = "";
  })
