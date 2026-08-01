#!/usr/bin/env bash
# Stamp every file under a gallery's source tree with one fixed mtime.
#
#   scripts/normalise-mtimes.sh <dir>...
#
# Why this exists: Munin copies each source image's filesystem mtime straight
# into the photo JSON (Sources/MuninKit/Photo+Read.swift -> `modifiedDate`),
# and git does not record mtimes. A fresh `git clone` or `actions/checkout`
# therefore stamps every `example/album/*.jpg` with the checkout time, and the
# gallery generated from it differs from any gallery generated anywhere else
# -- in 104 of 936 files, as it happens. That byte-for-byte comparison is the
# whole point of scripts/smoke-static.sh, so without this the parity gate can
# only pass on the machine that produced the baseline. Deleting this step
# turns CI red on the next fresh checkout.
#
# Both sides of the comparison have to be produced this way: the staged copy
# in smoke-static.sh, and the committed example/content
# (scripts/regen-example-content.sh). They then agree by construction rather
# than by coincidence of when the tree was checked out.
#
# The instant itself is arbitrary. 2001-01-01T00:00:00Z is Foundation's
# reference date, picked only because it is unmistakably synthetic when you
# meet it as a `modifiedDate` in a JSON file. Changing it invalidates
# example/content; regenerate the baseline in the same commit.
set -euo pipefail

[ $# -gt 0 ] || { echo "usage: $(basename "$0") <dir>..." >&2; exit 2; }

for dir; do
  [ -d "$dir" ] || { echo "error: not a directory: $dir" >&2; exit 1; }
  # `touch -t` rather than `-d @<epoch>`: BSD touch has no @epoch form. -t is
  # interpreted in local time, so TZ=UTC is what makes the stamp mean the same
  # instant on every machine.
  TZ=UTC find "$dir" -exec touch -t 200101010000.00 {} +
done
