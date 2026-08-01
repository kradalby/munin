//
//  File.c
//  
//
//  Created by Tobias Haeberle on 22.06.21.
//

#include "Cvips.h"


VipsImage* shim_vips_image_new_from_source(VipsSource *source, const char* options)
{
   return vips_image_new_from_source(source, options);
}
