import Cvips
import CvipsShim

extension VIPSImage {
    /// A structure representing the dimensions of an image.
    public struct Size {
        /// The width of the image in pixels.
        public var width: Int
        /// The height of the image in pixels.
        public var height: Int
        
        /// Creates a new Size with the specified width and height.
        /// - Parameters:
        ///   - width: The width in pixels
        ///   - height: The height in pixels
        public init(width: Int, height: Int) {
            self.width = width
            self.height = height
        }
    }
    
    /// The size of the image as a Size struct containing width and height.
    /// - Returns: A Size struct with the image dimensions in pixels
    public var size: Size {
        return Size(width: Int(vips_image_get_width(self.image)),
                    height: Int(vips_image_get_height(self.image)))
    }
    
    /// The number of pixels across the image.
    /// - Returns: The image width in pixels
    public var width: Int {
        return Int(vips_image_get_width(self.image))
    }
    
    /// The number of pixels down the image.
    /// - Returns: The image height in pixels
    public var height: Int {
        return Int(vips_image_get_height(self.image))
    }
    
    /// The number of bands (channels) in the image.
    /// 
    /// For example, RGB images have 3 bands, RGBA images have 4 bands,
    /// and grayscale images have 1 band.
    /// - Returns: The number of bands in the image
    public var bands: Int {
        Int(vips_image_get_bands(self.image))
    }
    
    /// The EXIF orientation value for the image.
    /// 
    /// Returns the orientation value from EXIF metadata, if present.
    /// Values range from 1-8 according to the EXIF specification.
    /// - Returns: The EXIF orientation value, or 1 if no orientation is set
    public var orientation: Int {
        Int(shim_vips_exif_orientation(self.image))
    }
    
    /// The interpretation of the image as a human-readable string.
    /// 
    /// This returns the string representation of the image's interpretation,
    /// such as "srgb", "rgb", "cmyk", "lab", etc.
    /// - Returns: A string describing the image interpretation
    public var space: String {
        return String(cString: vips_enum_nick(vips_interpretation_get_type(), self.image.pointee.Type.rawValue))
    }
    
    /// Whether the image has an alpha channel.
    /// 
    /// This checks if the image has transparency information. For example,
    /// RGBA images return true, while RGB images return false.
    /// - Returns: `true` if the image has an alpha channel, `false` otherwise
    public var hasAlpha: Bool {
        return (vips_image_hasalpha(self.image) != 0)
    }
    
    /// Whether the image has an embedded ICC color profile.
    /// 
    /// ICC profiles contain information about the color characteristics
    /// of the image and are used for accurate color reproduction.
    /// - Returns: `true` if the image has an ICC profile, `false` otherwise
    public var hasProfile: Bool {
        let iccName = "icc-profile-data"
        return vips_image_get_typeof(self.image, iccName) != 0;
    }
    
    /// The format of each band element.
    /// 
    /// This describes the numeric format used to store pixel values,
    /// such as unsigned 8-bit integers, 32-bit floats, etc.
    /// - Returns: The band format as a VipsBandFormat enum value
    public var format: VipsBandFormat {
        return vips_image_get_format(self.image)
    }

    /// The interpretation set in the image header.
    /// 
    /// This describes how the pixel values should be interpreted,
    /// such as RGB, CMYK, LAB, etc. Use `guess_format` if you want
    /// a sanity-checked value.
    /// - Returns: The interpretation as a VipsInterpretation enum value
    public var interpretation: VipsInterpretation {
        return vips_image_get_interpretation(self.image)
    }

    /// The coding format from the image header.
    /// 
    /// This describes how the pixel data is encoded, such as:
    /// - `VIPS_CODING_NONE`: Uncompressed pixel data
    /// - `VIPS_CODING_LABQ`: Lab with Q encoding
    /// - `VIPS_CODING_RAD`: Radiance HDR encoding
    /// - Returns: The coding as a VipsCoding enum value
    public var coding: VipsCoding {
        return vips_image_get_coding(self.image)
    }
    
    /// The horizontal image resolution in pixels per millimeter.
    /// 
    /// This represents the physical resolution of the image when printed
    /// or displayed. A value of 1.0 means 1 pixel per millimeter.
    /// - Returns: The horizontal resolution in pixels per millimeter
    public var xres: Double {
        return vips_image_get_xres(self.image)
    }
    
    /// The vertical image resolution in pixels per millimeter.
    /// 
    /// This represents the physical resolution of the image when printed
    /// or displayed. A value of 1.0 means 1 pixel per millimeter.
    /// - Returns: The vertical resolution in pixels per millimeter
    public var yres: Double {
        return vips_image_get_yres(self.image)
    }
    
    /// The horizontal position of the image origin, in pixels.
    /// 
    /// This is a hint about where this image should be positioned relative
    /// to some larger canvas. It's often used in image tiling operations.
    /// - Returns: The horizontal offset in pixels
    public var xoffset: Int {
        return Int(vips_image_get_xoffset(self.image))
    }
    
    /// The vertical position of the image origin, in pixels.
    /// 
    /// This is a hint about where this image should be positioned relative
    /// to some larger canvas. It's often used in image tiling operations.
    /// - Returns: The vertical offset in pixels
    public var yoffset: Int {
        return Int(vips_image_get_yoffset(self.image))
    }
    
    /// The name of the file the image was loaded from.
    /// 
    /// Returns the filename that was used to load this image, or `nil`
    /// if the image was created programmatically or from memory.
    /// - Returns: The filename, or `nil` if no filename is available
    public var filename: String? {
        guard let cString = vips_image_get_filename(self.image) else { return nil }
        return String(cString: cString)
    }
    
    /// The scale factor for matrix images.
    /// 
    /// Matrix images can have an optional scale field for use by integer
    /// convolution operations. The scale is applied after convolution
    /// to normalize the result.
    /// - Returns: The scale factor, typically 1.0 for non-matrix images
    public var scale: Double {
        return vips_image_get_scale(self.image)
    }
    
    /// The offset value for matrix images.
    /// 
    /// Matrix images can have an optional offset field for use by integer
    /// convolution operations. The offset is added after convolution
    /// and scaling.
    /// - Returns: The offset value, typically 0.0 for non-matrix images
    public var offset: Double {
        return vips_image_get_offset(self.image)
    }
    
    /// The height of each page in multi-page images.
    /// 
    /// Multi-page images (such as animated GIFs or multi-page TIFFs) can have
    /// a page height different from the total image height. If page-height is
    /// not set, it defaults to the image height.
    /// - Returns: The height of each page in pixels
    public var pageHeight: Int {
        return Int(vips_image_get_page_height(self.image))
    }
    
    /// The number of pages in the image file.
    /// 
    /// This is the number of pages in the original image file, not necessarily
    /// the number of pages that have been loaded into this image object.
    /// For single-page images, this returns 1.
    /// - Returns: The number of pages in the image file
    public var nPages: Int {
        return Int(vips_image_get_n_pages(self.image))
    }
    
    /// The number of sub-image file directories.
    /// 
    /// Some image formats (particularly TIFF) can contain multiple sub-images
    /// or sub-directories. This returns the count of such structures.
    /// Returns 0 if not present or not applicable to the format.
    /// - Returns: The number of sub-IFDs in the image file
    public var nSubifds: Int {
        return Int(vips_image_get_n_subifds(self.image))
    }
    
    /// Whether applying the orientation would swap width and height.
    /// 
    /// Some EXIF orientations require rotating the image by 90 or 270 degrees,
    /// which would swap the width and height dimensions. This property
    /// indicates if such a swap would occur.
    /// - Returns: `true` if width and height would swap when applying orientation
    public var orientationSwap: Bool {
        return vips_image_get_orientation_swap(self.image) != 0
    }
    
    /// The image mode as a string.
    /// 
    /// This is an optional string field that can be used to store additional
    /// information about how the image should be interpreted or processed.
    /// - Returns: The mode string, or `nil` if no mode is set
    public var mode: String? {
        guard let cString = vips_image_get_mode(self.image) else { return nil }
        return String(cString: cString)
    }
    
    /// Get the concurrency hint for this image.
    /// 
    /// This returns the suggested level of parallelism for operations on this
    /// image. It can be used to optimize performance by limiting the number
    /// of threads used for processing.
    /// 
    /// - Parameter defaultConcurrency: The default value to return if no hint is set
    /// - Returns: The suggested concurrency level
    public func concurrency(default defaultConcurrency: Int = 1) -> Int {
        return Int(vips_image_get_concurrency(self.image, Int32(defaultConcurrency)))
    }
    
    /// The processing history of the image.
    /// 
    /// VIPS maintains a log of operations that have been performed on an image.
    /// This can be useful for debugging or understanding how an image was created.
    /// - Returns: The history string, or `nil` if no history is available
    public var history: String? {
        guard let cString = vips_image_get_history(self.image) else { return nil }
        return String(cString: cString)
    }

    /// Get the value of the pixel at the specified coordinates.
    /// 
    /// This is a convenience method that calls the main `getpoint` implementation.
    /// The pixel value is returned as an array of doubles, with one element
    /// per band in the image.
    /// 
    /// - Parameters:
    ///   - x: The horizontal coordinate (0-based)
    ///   - y: The vertical coordinate (0-based)
    /// - Returns: An array of double values representing the pixel, one per band
    /// - Throws: VIPSError if the coordinates are out of bounds or another error occurs
    public func getpoint(_ x: Int, _ y: Int) throws -> [Double] {
        try self.getpoint(x: x, y: y)
    }
}
