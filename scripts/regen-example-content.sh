#!/usr/bin/env bash
# Regenerate the committed example/content parity baseline.
#
#   scripts/regen-example-content.sh <munin-binary>
#
# The baseline scripts/smoke-static.sh diffs against, so it has to be
# reproducible from a fresh checkout. That needs the source mtimes normalised
# first (see normalise-mtimes.sh), which is why this is a script and not three
# lines in a README: skip that step and it passes locally, fails in CI.
#
# Use a static build (`nix build .#munin-static-amd64`). The two musl triples
# agree byte for byte, but a dynamic build links whatever libvips the distro
# ships and its thumbnails differ.
#
# Rewrites example/album mtimes in the working tree: harmless, and leaves the
# tree in the state CI sees.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

BIN="${1:-}"
[ -n "$BIN" ] || { echo "usage: $(basename "$0") <munin-binary>" >&2; exit 2; }
[ -x "$BIN" ] || { echo "error: not an executable: $BIN" >&2; exit 1; }
BIN="$(cd "$(dirname "$BIN")" && pwd)/$(basename "$BIN")"

echo "== normalising example/album mtimes"
"$REPO/scripts/normalise-mtimes.sh" "$REPO/example/album"

echo "== regenerating example/content with $BIN"
rm -rf "$REPO/example/content"
(cd "$REPO/example" && "$BIN")

echo "== done; review with: git status --short example/content"
