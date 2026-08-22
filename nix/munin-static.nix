# A `munin` that needs no dynamic loader and no shared libraries: the kernel
# runs it directly and it reads nothing from the filesystem to start. That is
# what lets one file run on any Linux of the right architecture.
#
# Both triples cross-compile from x86_64-linux; `arch` picks which.
# See nix/README.md.
{
  pkgs,
  repo,
  arch ? "x86_64",
  config ? "release",
}: let
  inherit (pkgs) lib;

  toolchain = import ./toolchain.nix {inherit pkgs;};
  sdk = import ./sdk.nix {inherit pkgs;};
  vips = import ./vips.nix {inherit pkgs arch;};

  triple = "${arch}-swift-linux-musl";

  crossPkgs = import ./cross-pkgs.nix {inherit pkgs arch;};

  # Every archive munin links, plus everything their .pc files name under
  # Requires/Requires.private: SwiftPM's parser walks those unconditionally
  # and drops all cflags when one is missing.
  cLibs = with crossPkgs; [
    vips
    glib
    expat
    libxml2
    libjpeg_turbo
    libpng
    libtiff
    zstd
    xz
    libdeflate
    libwebp
    libexif
    libiptcdata
    cgif
    libhwy
    pcre2
    libffi
    zlib
    gettext
    util-linux
    libselinux
    libsepol
    libsysprof-capture
  ];

  # nixpkgs' static musl zlib ships libz.a and no zlib.pc. vips.pc Requires
  # zlib, so its absence drops every cflag -- surfacing as "'glib.h' file not
  # found", several layers from the cause.
  zlibPc = pkgs.writeTextFile {
    name = "zlib-pc-static";
    destination = "/lib/pkgconfig/zlib.pc";
    text = ''
      prefix=${crossPkgs.zlib}
      libdir=${crossPkgs.zlib}/lib
      includedir=${crossPkgs.zlib.dev}/include

      Name: zlib
      Description: zlib compression library
      Version: ${crossPkgs.zlib.version}
      Libs: -L''${libdir} -lz
      Cflags: -I''${includedir}
    '';
  };

  # Every output, not `${p}`: glib's default is `bin`, while the archives and
  # the compiled-in prefixes live in `out`. A rule written against the default
  # silently misses it, here and in remove-references-to below.
  cLibPaths = lib.concatMap (p: p.all or [p]) cLibs;

  prefix = pkgs.symlinkJoin {
    name = "munin-c-closure-${arch}";
    paths = cLibPaths ++ [zlibPc];
  };

  # glib-2.0.pc's Libs names -latomic; the Static SDK has none (its atomics
  # are in compiler-rt). nixpkgs' musl cross-gcc ships one.
  gccMuslLibs = "${crossPkgs.stdenv.cc.cc.lib}/${crossPkgs.stdenv.hostPlatform.config}/lib";

  # By content, so a Sources/ edit does not re-clone ten git repositories.
  resolved = builtins.path {
    path = ../Package.resolved;
    name = "Package.resolved";
  };

  deps = import ./deps.nix {
    inherit pkgs resolved;
    hash = "sha256-kkHFY//2vANHYgZb5TE+g2ZMveMe8PiGL57gHDs8uPU=";
  };

  # Allowlist: example/ is hundreds of megabytes, and `src = self` makes
  # every README commit a fresh build of the whole package.
  src = lib.cleanSourceWith {
    name = "munin-source";
    src = repo;
    filter = path: _type: let
      rel = lib.removePrefix "${toString repo}/" (toString path);
      top = lib.head (lib.splitString "/" rel);
    in
      builtins.elem top [
        "Sources"
        "Tests"
        "assets"
        "Package.swift"
        "Package.resolved"
      ];
  };
in
  pkgs.stdenvNoCC.mkDerivation {
    pname = "munin-static-${arch}";
    version = "0";
    inherit src;

    nativeBuildInputs = [
      toolchain
      pkgs.jq
      pkgs.file
      pkgs.binutils
      pkgs.pkg-config
      pkgs.removeReferencesTo
    ];

    # No network, so hand SwiftPM an already-resolved workspace. Both files
    # derive from Package.resolved; there is no second revision list.
    configurePhase = ''
      runHook preConfigure

      mkdir -p .build/checkouts
      cp -r ${deps}/* .build/checkouts/
      chmod -R u+w .build/checkouts

      jq '{
        object: {
          artifacts: [],
          prebuilts: [],
          dependencies: [
            .pins[] | (.location | sub("\\.git$"; "") | split("/") | last) as $name | {
              basedOn: null,
              packageRef: {
                identity: .identity,
                kind: .kind,
                location: .location,
                name: $name
              },
              state: { checkoutState: .state, name: "sourceControlCheckout" },
              subpath: $name
            }
          ]
        },
        version: 7
      }' Package.resolved > .build/workspace-state.json

      runHook postConfigure
    '';

    buildPhase = ''
      runHook preBuild

      export HOME=$TMPDIR
      export PKG_CONFIG_PATH=${prefix}/lib/pkgconfig

      # SwiftPM reads a .pc file's Libs but not Requires.private, so the link
      # comes up short by every transitive archive (libdeflate/lzma/zstd via
      # libtiff, blkid/mount via gio). pkg-config --static computes it in
      # link order.
      linkArgs=""
      for f in $(pkg-config --static --libs vips libexif libiptcdata); do
        case "$f" in
          -L*|-l*) linkArgs="$linkArgs -Xlinker $f" ;;
        esac
      done

      swift build -c ${config} \
        --swift-sdk ${triple} \
        --swift-sdks-path ${sdk} \
        --disable-automatic-resolution \
        --scratch-path .build \
        -Xcc -I${prefix}/include \
        -Xlinker -L${gccMuslLibs} \
        $linkArgs \
        ${lib.optionalString (config == "release") "-Xlinker -s"}

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      bin=.build/${triple}/${config}/munin
      file "$bin"
      # PT_INTERP names a dynamic loader, DT_NEEDED a shared library. Either
      # one means the binary depends on something being installed.
      readelf -lW "$bin" | grep -q INTERP && { echo "FAIL: needs a loader"; exit 1; }
      readelf -dW "$bin" | grep -q NEEDED && { echo "FAIL: needs shared libs"; exit 1; }
      install -Dm755 "$bin" $out/bin/munin

      # vips and glib compile their module and locale prefixes in as string
      # literals. Nothing reads them -- modules are disabled and the binary
      # loads no libraries at all -- but nix sees store paths and retains the
      # entire C closure, several times the size of the binary. The smoke
      # check is what proves they are dead.
      remove-references-to \
        ${lib.concatMapStringsSep " \\\n        " (p: "-t ${p}") cLibPaths} \
        $out/bin/munin

      # remove-references-to rewrites the hash to 32 'e's rather than deleting
      # the string, so only a real hash is a failure.
      live=$(grep -ao '/nix/store/[a-z0-9]\{32\}-[a-zA-Z0-9._+-]*' $out/bin/munin \
               | grep -v '^/nix/store/e\{32\}-' | sort -u || true)
      if [ -n "$live" ]; then
        echo "FAIL: live store references left in the binary:" >&2
        echo "$live" >&2
        exit 1
      fi

      runHook postInstall
    '';

    meta = {
      description = "Static Linux munin (${triple})";
      platforms = ["x86_64-linux"];
      mainProgram = "munin";
    };
  }
