# A gallery built by a static munin: $out is its content/ tree.
#
# Runs with env -i in the sandbox -- no host libc, no /usr/share, no locale,
# tz database or fontconfig -- which is the portability assertion for the
# static binary. A foreign arch runs under qemu-user, which needs no binfmt
# registration.
{
  pkgs,
  name,
  # A gallery directory: munin.json plus its sourceFolder.
  gallery,
  munin,
  emulator ? null,
}:
pkgs.runCommand "munin-gallery-${name}" {} ''
  cp -r ${gallery} work
  chmod -R u+w work
  rm -rf work/content

  # Munin copies each source's mtime into its photo JSON, and neither git nor
  # the store keeps a meaningful one. Any fixed instant works; changing it
  # changes every generated JSON.
  TZ=UTC find work -exec touch -t 200101010000.00 {} +

  (cd work && env -i ${pkgs.lib.optionalString (emulator != null) emulator} ${munin}/bin/munin)

  mv work/content $out
''
