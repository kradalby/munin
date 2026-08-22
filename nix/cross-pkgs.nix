# The static-musl package set for both the C closure and the final link.
#
# Shared, so vips cannot compile against one libwebp while pkg-config hands
# the linker another. Overrides are an overlay for the same reason: they reach
# transitive references, which a per-use-site override would not.
{
  pkgs,
  arch,
}: let
  base =
    {
      x86_64 = pkgs.pkgsCross.musl64;
      aarch64 = pkgs.pkgsCross.aarch64-multiplatform-musl;
    }
    .${arch};
in
  base.pkgsStatic.extend (_final: prev: {
    # giflib builds a .so unconditionally and fails to link under pkgsStatic.
    # It reaches us only via libwebp's CLI tools; vips reads GIF through cgif.
    libwebp = prev.libwebp.override {gifSupport = false;};

    # Its test suite cross-compiles hundreds of binaries, longer than the rest
    # of the closure put together. Nothing links them.
    libhwy = prev.libhwy.overrideAttrs {doCheck = false;};

    # CMake falls back to a scalar codec when it finds no assembler (nasm on
    # x86_64; aarch64 needs none), at 2-4x on JPEG encode -- munin's hot path.
    #
    # Nothing downstream can see it: SIMD and scalar are bit-identical, so
    # example/content does not move and the smoke checks stay green. Encoding
    # the gallery under JSIMD_FORCENONE=1 changes not one file.
    #
    # Asserted at the library so the archive cannot exist without it, and vips
    # gets the guarantee too. It has to be an absence test: a scalar build
    # carries no member matching "simd" at all. Dispatch (jsimd.c.o) and the
    # kernels are checked separately -- dispatch with no kernels is still
    # scalar at runtime.
    libjpeg_turbo = prev.libjpeg_turbo.overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          members=$($AR t $out/lib/libjpeg.a)
          kernels=$(printf '%s\n' "$members" | grep -c -e '\.asm\.o$' -e '-neon\.c\.o$' || true)
          if ! printf '%s\n' "$members" | grep -qx 'jsimd.c.o'; then
            echo "FAIL: libjpeg.a has no jsimd.c.o -- scalar JPEG codec." >&2
            echo "      On x86_64 this means the build found no assembler; nasm" >&2
            echo "      must be in nativeBuildInputs. aarch64 needs none." >&2
            exit 1
          fi
          if [ "$kernels" -eq 0 ]; then
            echo "FAIL: libjpeg.a has SIMD dispatch but no accelerated objects." >&2
            exit 1
          fi
          echo "libjpeg.a: SIMD dispatch plus $kernels accelerated objects"
        '';
    });
  })
