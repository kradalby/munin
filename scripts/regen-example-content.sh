#!/usr/bin/env bash
# Regenerate the committed example/content parity baseline.
#
#   scripts/regen-example-content.sh <munin-binary>
#
# example/content is what scripts/smoke-static.sh diffs the static build
# against, so it has to be reproducible from a fresh checkout by anyone. That
# means normalising the source mtimes first -- see the long comment in
# scripts/normalise-mtimes.sh for why -- and it is the reason this is a script
# and not three commands in a README: a baseline regenerated without that step
# passes locally and fails in CI.
#
# Any munin build produces the same tree (the glibc and both musl builds are
# byte-identical here; that equivalence is what the smoke test asserts), so
# use whichever is at hand -- the glibc one needs no sysroot.
#
# Note this rewrites the mtimes of example/album in the working tree. That is
# intentional and harmless: git does not track mtimes, and it leaves the tree
# in the state CI will see.
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
