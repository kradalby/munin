# SwiftPM's checkouts as one fixed-output derivation: the sandbox has no
# network, so `swift build` cannot resolve.
#
# Read straight from Package.resolved, so there is no second revision list --
# only the outputHash, like a Go vendorHash.
{
  pkgs,
  resolved,
  hash,
}:
pkgs.stdenvNoCC.mkDerivation {
  name = "munin-swiftpm-deps";

  nativeBuildInputs = [pkgs.git pkgs.jq pkgs.cacert];

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = hash;

  buildCommand = ''
    export GIT_CONFIG_GLOBAL=$TMPDIR/gitconfig
    export GIT_TERMINAL_PROMPT=0
    mkdir -p $out

    jq -r '.pins[] | [.location, .state.revision] | @tsv' ${resolved} \
    | while IFS=$'\t' read -r url rev; do
        name=$(basename "$url" .git)
        git clone --quiet --no-checkout "$url" "$out/$name"
        git -C "$out/$name" checkout --quiet --detach "$rev"
        git -C "$out/$name" submodule --quiet update --init --recursive
        # .git is the only nondeterministic part of a checkout; drop it and
        # what is left is content-addressable.
        find "$out/$name" -name .git -prune -exec rm -rf {} +
      done
  '';
}
