#include "include/MuninVipsShim.h"

VipsImage *mv_open(const char *path) {
  return vips_image_new_from_file(path, NULL);
}

int mv_thumbnail(VipsImage *in, VipsImage **out, int width) {
  return vips_thumbnail_image(in, out, width, NULL);
}

// Does the named operation declare a `Q` (quality) argument?
//
// vips_call hard-errors on an argument the operation does not declare, and
// libvips only gives `Q` to the savers where a quality number means
// something: the lossy and quantising ones (jpeg, webp, tiff, png, ...).
// The lossless and palette formats (ppm, gif, raw, ...) have no such knob.
// Munin names each scaled output after its source file and its input
// extensions are user-configurable, so which saver runs is the operator's
// choice -- ask the class rather than carry a list of formats that goes
// stale the next time libvips adds a saver.
static int mv_saver_takes_quality(const char *saver) {
  GType type = vips_type_find("VipsOperation", saver);
  if (type == 0) {
    return 0;
  }
  GObjectClass *klass = g_type_class_ref(type);
  int found = g_object_class_find_property(klass, "Q") != NULL;
  g_type_class_unref(klass);
  return found;
}

int mv_save(VipsImage *in, const char *path, int quality) {
  // vips_foreign_find_save maps the filename suffix to a saver nickname and
  // sets the error buffer if there is none. vips_call then invokes it with
  // its two required arguments (in, filename), plus Q where there is one.
  const char *saver = vips_foreign_find_save(path);
  if (saver == NULL) {
    return -1;
  }
  if (mv_saver_takes_quality(saver)) {
    return vips_call(saver, in, path, "Q", quality, NULL);
  }
  return vips_call(saver, in, path, NULL);
}
