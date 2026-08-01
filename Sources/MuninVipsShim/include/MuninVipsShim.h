#ifndef MUNIN_VIPS_SHIM_H
#define MUNIN_VIPS_SHIM_H

// See the comment in Sources/Cvips/Cvips.h for why <termios.h> comes first.
// It is here as well as there because swift-vips carried it in *both* of its
// vips-wrapping headers, and that pair is the arrangement with a track record
// on macOS -- the one platform this repository cannot build locally.
#include <termios.h>
#include <vips/vips.h>

// libvips' operation entry points are NULL-terminated C variadics, which
// Swift cannot call at all. This target exists for that one reason: it pins
// each of them to a fixed arity that Swift can import.
//
// It is deliberately not a general libvips binding. Munin performs exactly
// three operations on an image -- open it, thumbnail it, save it -- and this
// header is the whole list. Everything else Munin needs from libvips
// (vips_init, vips_concurrency_set, the vips_cache_* setters, the
// vips_image_get_* accessors, g_object_unref) is already a fixed-arity
// function that Swift imports directly from Cvips.

// vips_image_new_from_file with no load options: random access, no forced
// memory load, i.e. libvips' own defaults. Returns a reference the caller
// owns, or NULL with the error buffer set.
VipsImage *mv_open(const char *path);

// vips_thumbnail_image with no target height, which libvips defaults to the
// target width: the image is shrunk to fit inside a `width` x `width` box,
// keeping its aspect ratio and applying the EXIF rotation. On success `*out`
// is a reference the caller owns.
int mv_thumbnail(VipsImage *in, VipsImage **out, int width);

// Encode to `path`, choosing the encoder from its extension -- Munin names
// each scaled output after its source file, so a PNG in gives a PNG out.
// `quality` is passed as the saver's `Q` where the saver declares one, and
// dropped where it does not: a format with no quality knob (GIF, PPM, ...)
// is written at its only setting rather than failing to be written at all.
int mv_save(VipsImage *in, const char *path, int quality);

#endif /* MUNIN_VIPS_SHIM_H */
