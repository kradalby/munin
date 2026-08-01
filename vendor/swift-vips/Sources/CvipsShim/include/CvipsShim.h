//
//  Header.h
//  
//
//  Created by Tobias on 28.06.21.
//

#ifndef C_vips_shim_h
#define C_vips_shim_h

#include "glib.h"
#include <termios.h>
#include <vips/vips.h>

VipsImage* shim_vips_image_new_from_source(VipsSource *source, const char* options);

gint shim_g_object_get_ref_count(GObject* object);

gboolean shim_g_is_object(const void * p);

GObject* shim_g_object(const void * p);

GType shim_g_object_type(const void * p);

VipsImage* shim_vips_image(const void * p);

VipsObject* shim_vips_object(const void *p);

VipsArea* shim_vips_area(const void *p);

int shim_vips_getpoint(void *image, double **values, int *n, int x, int y);

GType shim_g_type_boolean();

GType shim_G_TYPE_STRING();

GType shim_G_TYPE_DOUBLE();

GType shim_VIPS_TYPE_ARRAY_DOUBLE();

GType shim_VIPS_TYPE_ARRAY_INT();

double* shim_vips_array_double(void *p, int n);

GType shim_G_TYPE_INT();

GType shim_VIPS_TYPE_BLOB();

GCallback shim_G_CALLBACK(void *f);

VipsSource* shim_VIPS_SOURCE(void *p);

VipsTarget* shim_VIPS_TARGET(void *p);

gulong shim_g_signal_connect(gpointer instance, const gchar *detailed_signal, GCallback c_handler, gpointer data);

int
shim_vips_exif_tag_to_int(VipsImage *image, const char *tag);

const char *
shim_vips_exif_tag(VipsImage *image, const char *tag);

int
shim_vips_exif_orientation(VipsImage *image);

static const char *SHIM_VIPS_META_ICC_NAME = VIPS_META_ICC_NAME;

static const char *EXIF_IFD0_ORIENTATION = "exif-ifd0-Orientation";

int shim_vips_copy_interpretation(VipsImage *in, VipsImage **out, VipsInterpretation interpretation);

VipsImage *
shim_vips_image_new_from_file( const char *name, VipsAccess access, gboolean inMemory);


int shim_vips_major_version();

const char* shim_vips_version();

#if VIPS_MAJOR_VERSION >= 8
#if VIPS_MINOR_VERSION >= 18
#define SHIM_VIPS_VERSION_8_18
#endif
#if VIPS_MINOR_VERSION >= 17
#define SHIM_VIPS_VERSION_8_17
#endif
#if VIPS_MINOR_VERSION >= 16
#define SHIM_VIPS_VERSION_8_16
#endif
#if VIPS_MINOR_VERSION >= 15
#define SHIM_VIPS_VERSION_8_15
#endif
#if VIPS_MINOR_VERSION >= 14
#define SHIM_VIPS_VERSION_8_14
#endif
#if VIPS_MINOR_VERSION >= 13
#define SHIM_VIPS_VERSION_8_13
// VipsSource helper functions
const char* shim_vips_connection_filename(VipsSource *source);
const char* shim_vips_connection_nick(VipsSource *source);
gint64 shim_vips_source_read_position(VipsSource *source);
gint64 shim_vips_source_length_internal(VipsSource *source);
gboolean shim_vips_source_decode_status(VipsSource *source);
gboolean shim_vips_source_is_pipe(VipsSource *source);

#endif
#endif

// Introspection functions for operation discovery
typedef struct {
    const char* nickname;
    const char* description;
    GType operation_type;
    int flags;
} ShimOperationInfo;

typedef struct {
    const char* name;
    const char* description;
    GType parameter_type;
    int flags;
    int priority;
} ShimParameterInfo;

// Get all operation types and count
GType* shim_get_all_operation_types(int* count);

// Get operation info by nickname
ShimOperationInfo* shim_get_operation_info(const char* nickname);

// Get parameters for an operation
ShimParameterInfo* shim_get_operation_parameters(const char* nickname, int* count);

// Free allocated arrays
void shim_free_operation_types(GType* types);
void shim_free_operation_info(ShimOperationInfo* info);
void shim_free_parameter_info(ShimParameterInfo* params);

// Helper functions for type introspection
const char* shim_gtype_name(GType gtype);
GType shim_gtype_fundamental(GType gtype);
gboolean shim_gtype_is_enum(GType gtype);
gboolean shim_gtype_is_flags(GType gtype);

// glib >= 2.86 tags GLogLevelFlags and GConnectFlags with
// __attribute__((flag_enum)), which changes how Swift's ClangImporter surfaces
// them: the G_LOG_LEVEL_* / G_CONNECT_* enumerators stop being importable as
// globals. C sees the same constants either way, so reading them through the
// shim keeps one Swift source building against both old and new glib.
guint shim_G_LOG_LEVEL_ERROR(void);
guint shim_G_LOG_LEVEL_WARNING(void);
guint shim_G_LOG_LEVEL_INFO(void);

// g_log_set_handler with G_LOG_LEVEL_MASK, which likewise cannot be named from
// Swift on new glib.
guint shim_g_log_set_handler_all(const gchar *domain, GLogFunc func, gpointer data);

GConnectFlags shim_G_CONNECT_DEFAULT(void);
GConnectFlags shim_G_CONNECT_AFTER(void);
GConnectFlags shim_G_CONNECT_SWAPPED(void);

#endif /* C_vips_shim_h */
