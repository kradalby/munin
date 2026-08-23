#!/usr/bin/env bash
# Stamp every file under a gallery's source tree with one fixed mtime.
#
#   scripts/normalise-mtimes.sh <dir>...
#
# Munin copies each source image's mtime into its photo JSON, and git does not
# record mtimes -- so a fresh checkout stamps every example/album/*.jpg with
# the checkout time and the generated gallery differs from everyone else's.
# Both sides of the smoke test's byte comparison have to be pinned this way, or
# it only passes on the machine that made the baseline.
#
# The instant is arbitrary (Foundation's reference date), picked to be
# obviously synthetic in a JSON file. Changing it invalidates example/content.
set -euo pipefail

[ $# -gt 0 ] || { echo "usage: $(basename "$0") <dir>..." >&2; exit 2; }

for dir; do
  [ -d "$dir" ] || { echo "error: not a directory: $dir" >&2; exit 1; }
  # `touch -t` rather than `-d @<epoch>`: BSD touch has no @epoch form. -t is
  # interpreted in local time, so TZ=UTC is what makes the stamp mean the same
  # instant on every machine.
  TZ=UTC find "$dir" -exec touch -t 200101010000.00 {} +
done
