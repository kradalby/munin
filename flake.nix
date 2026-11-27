{
  # One Swift, nixpkgs', pinned by flake.lock, on every system.
  #
  #   default (x86_64-linux)    static musl binary, needs nothing installed
  #   munin-static-{amd64,arm64} same, both crossed from x86_64-linux
  #   default (others)          dynamic build, what `swift build` makes
  #
  # See nix/README.md.

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
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ];

    # Both static triples cross from here; the musl C closure is only
    # assembled for this build platform.
    buildSystem = "x86_64-linux";

    pkgsFor = system: import nixpkgs {inherit system;};
    buildPkgs = pkgsFor buildSystem;

    # Allowlists, so an unrelated edit does not rebuild: example/ is hundreds
    # of megabytes, and `src = self` makes every README commit a fresh build.
    only = root: paths:
      lib.fileset.toSource {
        inherit root;
        fileset = lib.fileset.unions paths;
      };

    swiftPaths = [./Sources ./Tests ./assets ./Package.swift ./Package.resolved];
    src = only ./. swiftPaths;
    testSrc = only ./. (swiftPaths ++ [./example]);
    lintSrc = only ./. [./Sources ./Tests ./Package.swift ./.swiftlint.yml];
    exampleSrc = only ./example [./example/album ./example/munin.json ./example/people.json];

    # A fixed-output fetch keyed on Package.resolved; nixpkgs' swiftpm unpack
    # hook lays it out as an already-resolved workspace.
    swiftpmDepsFor = pkgs:
      pkgs.swiftPackages.fetchSwiftPMDeps {
        inherit src;
        hash = "sha256-/Nx9n5DvFMzFzBqkESEu6hsGv4HmdIFTRWKbRzViH8Q=";
      };

    dynamicFor = pkgs:
      import ./nix/munin.nix {
        inherit pkgs src testSrc;
        swiftpmDeps = swiftpmDepsFor pkgs;
      };

    staticFor = arch:
      import ./nix/munin-static.nix {
        pkgs = buildPkgs;
        inherit src arch;
        swiftpmDeps = swiftpmDepsFor buildPkgs;
      };

    emulatorFor = arch:
      lib.optionalString (arch != "x86_64") "${buildPkgs.qemu-user}/bin/qemu-${arch}";

    galleryFor = arch: name: gallery:
      import ./nix/gallery.nix {
        pkgs = buildPkgs;
        name = "${name}-${arch}";
        inherit gallery;
        munin = staticFor arch;
        emulator = emulatorFor arch;
      };

    # Every generated file byte-identical to the committed baseline, so a
    # libvips or encoder change shows up on the commit that bumps flake.lock.
    # Both triples diff the same tree: they agree byte for byte.
    #
    # Then PNG, WebP and TIFF from other people's encoders (see
    # nix/testdata/README.md): example/ is all JPEG, so a JPEG-only libvips
    # passes the diff. Munin names each output after its source extension, so
    # this covers load and save.
    smokeCheck = arch: let
      formats = galleryFor arch "formats" ./nix/testdata/formats;
    in
      buildPkgs.runCommand "munin-smoke-${arch}" {
        nativeBuildInputs = [buildPkgs.diffutils];
      } ''
        # --no-dereference: the *_original files are relative links into album/,
        # which neither tree here contains.
        diff -r --no-dereference ${./example/content} ${galleryFor arch "example" exampleSrc}

        magic() { od -An -v -tx1 -N "''${2:-4}" -j "''${3:-0}" "$1" | tr -d ' \n'; }
        fmt=${formats}/formats/Formats
        [ "$(magic $fmt/png_sample_100.png)" = 89504e47 ]
        [ "$(magic $fmt/webp_sample_100.webp)" = 52494646 ]
        [ "$(magic $fmt/webp_sample_100.webp 4 8)" = 57454250 ]
        case "$(magic $fmt/tiff_sample_100.tif)" in 49492a00|4d4d002a) ;; *) exit 1 ;; esac

        touch $out
      '';
  in {
    packages = lib.genAttrs systems (system: let
      pkgs = pkgsFor system;
      dynamic = dynamicFor pkgs;
    in
      {
        munin-dynamic = dynamic;
        default = dynamic;
      }
      // lib.optionalAttrs (system == buildSystem) rec {
        munin-static-amd64 = staticFor "x86_64";
        munin-static-arm64 = staticFor "aarch64";
        default = munin-static-amd64;

        # What example/content should be; `nix run .#regen-example-content`
        # writes it there.
        example-content = galleryFor "x86_64" "example" exampleSrc;

        # Separate attr so a bad download.swift.org fetch fails in seconds.
        swift-static-sdk = import ./nix/sdk.nix {pkgs = buildPkgs;};
      });

    apps.${buildSystem}.regen-example-content = {
      type = "app";
      program = toString (buildPkgs.writeShellScript "regen-example-content" ''
        set -euo pipefail
        [ -f Package.swift ] || { echo "run from the repository root" >&2; exit 1; }
        rm -rf example/content
        cp -r --no-preserve=mode ${self.packages.${buildSystem}.example-content} example/content
        echo "review with: git status --short example/content"
      '');
    };

    # munin-gallery, not munin: nixpkgs' `munin` is the resource monitoring
    # tool, and shadowing it would swap a monitoring host's daemon.
    #
    # Ignores final/prev and uses this flake's pinned nixpkgs on purpose:
    # thumbnails are a function of the libvips version, and example/content is
    # the baseline for that one.
    overlays.default = _final: prev:
      lib.optionalAttrs (prev.stdenv.hostPlatform.system == buildSystem) {
        munin-gallery = staticFor "x86_64";
      };

    checks = lib.genAttrs systems (system:
      {
        unit = (dynamicFor (pkgsFor system)).tests.unit;
      }
      // lib.optionalAttrs (system == buildSystem) {
        smoke-amd64 = smokeCheck "x86_64";
        smoke-arm64 = smokeCheck "aarch64";

        # Not --strict: that promotes the current warnings to errors.
        lint =
          buildPkgs.runCommand "munin-swiftlint" {
            nativeBuildInputs = [buildPkgs.swiftlint];
          } ''
            cd ${lintSrc}
            swiftlint lint --no-cache
            touch $out
          '';
      });

    devShells = lib.genAttrs systems (system: let
      pkgs = pkgsFor system;
    in {
      # The package's own stdenv and inputs, so `swift build` here links what
      # the package links -- with an rpath, so the binary runs.
      default = (pkgs.mkShell.override {inherit (pkgs.swiftPackages) stdenv;}) {
        inputsFrom = [(dynamicFor pkgs)];
        packages = [pkgs.swiftlint pkgs.swiftPackages.swift-format];
      };
    });
  };
}
