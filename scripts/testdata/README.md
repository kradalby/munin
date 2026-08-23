# Format fixtures

`formats/` is a gallery, so this file lives beside it rather than inside it --
anything in the gallery directory has to be deleted again after staging.

Three 200x150 crops of `example/album/Misc/20180510-171752-IMG_7165.jpg`, encoded
by **independent** libraries (ImageMagick's libpng/libtiff, Google's `cwebp`), so
that decoding them proves libvips' `pngload`/`tiffload`/`webpload` work rather
than proving our own encoder round-trips.

`scripts/smoke-static.sh` builds this gallery with the static binary and checks
the magic bytes of every output. Munin names each scaled output after its source
extension, so this exercises the save side too (`pngsave`, `tiffsave`,
`webpsave`).

JPEG is not here on purpose: the `example/` run right above it is 104 JPEGs.

The basenames deliberately differ (`png_sample`, `tiff_sample`, `webp_sample`).
Two sources in one album that share a basename and differ only in extension both
map to the same `<basename>.json`; Munin now refuses to build such a gallery
(`MuninError.outputPathCollision`). Sharing a basename
here would therefore make this fixture fail rather than flake -- and this
fixture is about decoding PNG/WebP/TIFF, not about collisions.

Regenerate with:

    convert src.jpg -resize 200x150! -strip -define png:compression-level=9 png_sample.png
    convert src.jpg -resize 200x150! -strip -compress Zip                   tiff_sample.tif
    cwebp -quiet -q 75 -resize 200 150 src.jpg -o                           webp_sample.webp
