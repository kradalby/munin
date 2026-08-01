import Cvips
import CvipsShim

public typealias VIPSProgress = Cvips.VipsProgress

public final class VIPSImage: VIPSImageProtocol {
    public var ptr: UnsafeMutableRawPointer!

    public var image: UnsafeMutablePointer<VipsImage>! {
        return self.ptr.assumingMemoryBound(to: VipsImage.self)
    }

    public init(_ ptr: UnsafeMutableRawPointer) {
        self.ptr = ptr
    }

    public init(_ image: UnsafeMutablePointer<VipsImage>) {
        self.ptr = UnsafeMutableRawPointer(image)
    }

    deinit {
        guard let ptr else { return }
        g_object_unref(ptr)
    }

    public func withVipsImage<R>(_ body: (UnsafeMutablePointer<VipsImage>) -> R) -> R {
        return body(self.image)
    }

    /// This function creates a VIPSImage from a memory area.
    /// The memory area must be a simple array, for example RGBRGBRGB, left-to-right, top-to-bottom.
    /// The memory will be copied into the image.
    @inlinable
    public convenience init(
        data: some Collection<UInt8>,
        width: Int,
        height: Int,
        bands: Int,
        format: VipsBandFormat
    ) throws {

        func createImage(from buffer: UnsafeRawBufferPointer) throws -> UnsafeMutablePointer<
            VipsImage
        > {
            guard
                let image = vips_image_new_from_memory_copy(
                    buffer.baseAddress,
                    buffer.count,
                    .init(width),
                    .init(height),
                    .init(bands),
                    format
                )
            else {
                throw VIPSError(vips_error_buffer())
            }
            return image
        }

        let maybe = try data.withContiguousStorageIfAvailable { buffer in
            try createImage(from: .init(buffer))
        }

        if let maybe = maybe {
            self.init(maybe)
        } else {
            let image = try Array(data)
                .withUnsafeBufferPointer { buffer in
                    try createImage(from: .init(buffer))
                }
            self.init(image)
        }
    }

    /// Creates a VIPSImage from signed 8-bit integer data with memory copy.
    ///
    /// This function creates a VipsImage from a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom. The memory will be copied into the image.
    ///
    /// - Parameters:
    ///   - data: Collection containing Int8 pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    @inlinable
    public convenience init(
        data: some Collection<Int8>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        func createImage(from buffer: UnsafeRawBufferPointer) throws -> UnsafeMutablePointer<
            VipsImage
        > {
            guard
                let image = vips_image_new_from_memory_copy(
                    buffer.baseAddress,
                    buffer.count,
                    .init(width),
                    .init(height),
                    .init(bands),
                    .char
                )
            else {
                throw VIPSError(vips_error_buffer())
            }
            return image
        }

        let maybe = try data.withContiguousStorageIfAvailable { buffer in
            try createImage(from: .init(buffer))
        }

        if let maybe = maybe {
            self.init(maybe)
        } else {
            let image = try Array(data)
                .withUnsafeBufferPointer { buffer in
                    try createImage(from: .init(buffer))
                }
            self.init(image)
        }
    }

    /// Creates a VIPSImage from unsigned 16-bit integer data with memory copy.
    ///
    /// This function creates a VipsImage from a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom. The memory will be copied into the image.
    ///
    /// - Parameters:
    ///   - data: Collection containing UInt16 pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    @inlinable
    public convenience init(
        data: some Collection<UInt16>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        func createImage(from buffer: UnsafeRawBufferPointer) throws -> UnsafeMutablePointer<
            VipsImage
        > {
            guard
                let image = vips_image_new_from_memory_copy(
                    buffer.baseAddress,
                    buffer.count,
                    .init(width),
                    .init(height),
                    .init(bands),
                    .ushort
                )
            else {
                throw VIPSError(vips_error_buffer())
            }
            return image
        }

        let maybe = try data.withContiguousStorageIfAvailable { buffer in
            try createImage(from: .init(buffer))
        }

        if let maybe = maybe {
            self.init(maybe)
        } else {
            let image = try Array(data)
                .withUnsafeBufferPointer { buffer in
                    try createImage(from: .init(buffer))
                }
            self.init(image)
        }
    }

    /// Creates a VIPSImage from signed 16-bit integer data with memory copy.
    ///
    /// This function creates a VipsImage from a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom. The memory will be copied into the image.
    ///
    /// - Parameters:
    ///   - data: Collection containing Int16 pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    @inlinable
    public convenience init(
        data: some Collection<Int16>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        func createImage(from buffer: UnsafeRawBufferPointer) throws -> UnsafeMutablePointer<
            VipsImage
        > {
            guard
                let image = vips_image_new_from_memory_copy(
                    buffer.baseAddress,
                    buffer.count,
                    .init(width),
                    .init(height),
                    .init(bands),
                    .short
                )
            else {
                throw VIPSError(vips_error_buffer())
            }
            return image
        }

        let maybe = try data.withContiguousStorageIfAvailable { buffer in
            try createImage(from: .init(buffer))
        }

        if let maybe = maybe {
            self.init(maybe)
        } else {
            let image = try Array(data)
                .withUnsafeBufferPointer { buffer in
                    try createImage(from: .init(buffer))
                }
            self.init(image)
        }
    }

    /// Creates a VIPSImage from unsigned 32-bit integer data with memory copy.
    ///
    /// This function creates a VipsImage from a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom. The memory will be copied into the image.
    ///
    /// - Parameters:
    ///   - data: Collection containing UInt32 pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    @inlinable
    public convenience init(
        data: some Collection<UInt32>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        func createImage(from buffer: UnsafeRawBufferPointer) throws -> UnsafeMutablePointer<
            VipsImage
        > {
            guard
                let image = vips_image_new_from_memory_copy(
                    buffer.baseAddress,
                    buffer.count,
                    .init(width),
                    .init(height),
                    .init(bands),
                    .uint
                )
            else {
                throw VIPSError(vips_error_buffer())
            }
            return image
        }

        let maybe = try data.withContiguousStorageIfAvailable { buffer in
            try createImage(from: .init(buffer))
        }

        if let maybe = maybe {
            self.init(maybe)
        } else {
            let image = try Array(data)
                .withUnsafeBufferPointer { buffer in
                    try createImage(from: .init(buffer))
                }
            self.init(image)
        }
    }

    /// Creates a VIPSImage from signed 32-bit integer data with memory copy.
    ///
    /// This function creates a VipsImage from a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom. The memory will be copied into the image.
    ///
    /// - Parameters:
    ///   - data: Collection containing Int32 pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    @inlinable
    public convenience init(
        data: some Collection<Int32>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        func createImage(from buffer: UnsafeRawBufferPointer) throws -> UnsafeMutablePointer<
            VipsImage
        > {
            guard
                let image = vips_image_new_from_memory_copy(
                    buffer.baseAddress,
                    buffer.count,
                    .init(width),
                    .init(height),
                    .init(bands),
                    .int
                )
            else {
                throw VIPSError(vips_error_buffer())
            }
            return image
        }

        let maybe = try data.withContiguousStorageIfAvailable { buffer in
            try createImage(from: .init(buffer))
        }

        if let maybe = maybe {
            self.init(maybe)
        } else {
            let image = try Array(data)
                .withUnsafeBufferPointer { buffer in
                    try createImage(from: .init(buffer))
                }
            self.init(image)
        }
    }

    /// Creates a VIPSImage from 32-bit floating point data with memory copy.
    ///
    /// This function creates a VipsImage from a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom. The memory will be copied into the image.
    ///
    /// - Parameters:
    ///   - data: Collection containing Float pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    @inlinable
    public convenience init(
        data: some Collection<Float>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        func createImage(from buffer: UnsafeRawBufferPointer) throws -> UnsafeMutablePointer<
            VipsImage
        > {
            guard
                let image = vips_image_new_from_memory_copy(
                    buffer.baseAddress,
                    buffer.count,
                    .init(width),
                    .init(height),
                    .init(bands),
                    .float
                )
            else {
                throw VIPSError(vips_error_buffer())
            }
            return image
        }

        let maybe = try data.withContiguousStorageIfAvailable { buffer in
            try createImage(from: .init(buffer))
        }

        if let maybe = maybe {
            self.init(maybe)
        } else {
            let image = try Array(data)
                .withUnsafeBufferPointer { buffer in
                    try createImage(from: .init(buffer))
                }
            self.init(image)
        }
    }

    /// Creates a VIPSImage from 64-bit floating point data with memory copy.
    ///
    /// This function creates a VipsImage from a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom. The memory will be copied into the image.
    ///
    /// - Parameters:
    ///   - data: Collection containing Double pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    @inlinable
    public convenience init(
        data: some Collection<Double>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        func createImage(from buffer: UnsafeRawBufferPointer) throws -> UnsafeMutablePointer<
            VipsImage
        > {
            guard
                let image = vips_image_new_from_memory_copy(
                    buffer.baseAddress,
                    buffer.count,
                    .init(width),
                    .init(height),
                    .init(bands),
                    .double
                )
            else {
                throw VIPSError(vips_error_buffer())
            }
            return image
        }

        let maybe = try data.withContiguousStorageIfAvailable { buffer in
            try createImage(from: .init(buffer))
        }

        if let maybe = maybe {
            self.init(maybe)
        } else {
            let image = try Array(data)
                .withUnsafeBufferPointer { buffer in
                    try createImage(from: .init(buffer))
                }
            self.init(image)
        }
    }

    /// Creates a VIPSImage from a memory area containing unsigned 8-bit integer data.
    ///
    /// This function wraps a VipsImage around a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom.
    ///
    /// **DANGER**: VIPS does not take responsibility for the memory area. The memory will NOT be copied
    /// into the image. You must ensure the memory remains valid for the lifetime of the image and all
    /// its descendants. Use the copy variant if you are unsure about memory management.
    ///
    /// - Parameters:
    ///   - buffer: Buffer containing UInt8 pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    public convenience init(
        unsafeData buffer: UnsafeBufferPointer<UInt8>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        guard
            let image = vips_image_new_from_memory(
                buffer.baseAddress,
                buffer.count,
                .init(width),
                .init(height),
                .init(bands),
                .uchar
            )
        else {
            throw VIPSError()
        }

        self.init(image)
    }

    /// Creates a VIPSImage from a memory area containing signed 8-bit integer data.
    ///
    /// This function wraps a VipsImage around a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom.
    ///
    /// **DANGER**: VIPS does not take responsibility for the memory area. The memory will NOT be copied
    /// into the image. You must ensure the memory remains valid for the lifetime of the image and all
    /// its descendants. Use the copy variant if you are unsure about memory management.
    ///
    /// - Parameters:
    ///   - buffer: Buffer containing Int8 pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    public convenience init(
        unsafeData buffer: UnsafeBufferPointer<Int8>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        guard
            let image = vips_image_new_from_memory(
                buffer.baseAddress,
                buffer.count,
                .init(width),
                .init(height),
                .init(bands),
                .char
            )
        else {
            throw VIPSError()
        }

        self.init(image)
    }

    /// Creates a VIPSImage from a memory area containing unsigned 16-bit integer data.
    ///
    /// This function wraps a VipsImage around a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom.
    ///
    /// **DANGER**: VIPS does not take responsibility for the memory area. The memory will NOT be copied
    /// into the image. You must ensure the memory remains valid for the lifetime of the image and all
    /// its descendants. Use the copy variant if you are unsure about memory management.
    ///
    /// - Parameters:
    ///   - buffer: Buffer containing UInt16 pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    public convenience init(
        unsafeData buffer: UnsafeBufferPointer<UInt16>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        guard
            let image = vips_image_new_from_memory(
                buffer.baseAddress,
                buffer.count,
                .init(width),
                .init(height),
                .init(bands),
                .ushort
            )
        else {
            throw VIPSError()
        }

        self.init(image)
    }

    /// Creates a VIPSImage from a memory area containing signed 16-bit integer data.
    ///
    /// This function wraps a VipsImage around a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom.
    ///
    /// **DANGER**: VIPS does not take responsibility for the memory area. The memory will NOT be copied
    /// into the image. You must ensure the memory remains valid for the lifetime of the image and all
    /// its descendants. Use the copy variant if you are unsure about memory management.
    ///
    /// - Parameters:
    ///   - buffer: Buffer containing Int16 pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    public convenience init(
        unsafeData buffer: UnsafeBufferPointer<Int16>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        guard
            let image = vips_image_new_from_memory(
                buffer.baseAddress,
                buffer.count,
                .init(width),
                .init(height),
                .init(bands),
                .short
            )
        else {
            throw VIPSError()
        }

        self.init(image)
    }

    /// Creates a VIPSImage from a memory area containing unsigned 32-bit integer data.
    ///
    /// This function wraps a VipsImage around a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom.
    ///
    /// **DANGER**: VIPS does not take responsibility for the memory area. The memory will NOT be copied
    /// into the image. You must ensure the memory remains valid for the lifetime of the image and all
    /// its descendants. Use the copy variant if you are unsure about memory management.
    ///
    /// - Parameters:
    ///   - buffer: Buffer containing UInt32 pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    public convenience init(
        unsafeData buffer: UnsafeBufferPointer<UInt32>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        guard
            let image = vips_image_new_from_memory(
                buffer.baseAddress,
                buffer.count,
                .init(width),
                .init(height),
                .init(bands),
                .uint
            )
        else {
            throw VIPSError()
        }

        self.init(image)
    }

    /// Creates a VIPSImage from a memory area containing signed 32-bit integer data.
    ///
    /// This function wraps a VipsImage around a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom.
    ///
    /// **DANGER**: VIPS does not take responsibility for the memory area. The memory will NOT be copied
    /// into the image. You must ensure the memory remains valid for the lifetime of the image and all
    /// its descendants. Use the copy variant if you are unsure about memory management.
    ///
    /// - Parameters:
    ///   - buffer: Buffer containing Int32 pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    public convenience init(
        unsafeData buffer: UnsafeBufferPointer<Int32>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        guard
            let image = vips_image_new_from_memory(
                buffer.baseAddress,
                buffer.count,
                .init(width),
                .init(height),
                .init(bands),
                .int
            )
        else {
            throw VIPSError()
        }

        self.init(image)
    }

    /// Creates a VIPSImage from a memory area containing 32-bit floating point data.
    ///
    /// This function wraps a VipsImage around a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom.
    ///
    /// **DANGER**: VIPS does not take responsibility for the memory area. The memory will NOT be copied
    /// into the image. You must ensure the memory remains valid for the lifetime of the image and all
    /// its descendants. Use the copy variant if you are unsure about memory management.
    ///
    /// - Parameters:
    ///   - buffer: Buffer containing Float pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    public convenience init(
        unsafeData buffer: UnsafeBufferPointer<Float>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        guard
            let image = vips_image_new_from_memory(
                buffer.baseAddress,
                buffer.count,
                .init(width),
                .init(height),
                .init(bands),
                .float
            )
        else {
            throw VIPSError()
        }

        self.init(image)
    }

    /// Creates a VIPSImage from a memory area containing 64-bit floating point data.
    ///
    /// This function wraps a VipsImage around a memory area. The memory area must be a simple array,
    /// for example RGBRGBRGB, left-to-right, top-to-bottom.
    ///
    /// **DANGER**: VIPS does not take responsibility for the memory area. The memory will NOT be copied
    /// into the image. You must ensure the memory remains valid for the lifetime of the image and all
    /// its descendants. Use the copy variant if you are unsure about memory management.
    ///
    /// - Parameters:
    ///   - buffer: Buffer containing Double pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bands: Number of bands per pixel
    /// - Throws: VIPSError if image creation fails
    public convenience init(
        unsafeData buffer: UnsafeBufferPointer<Double>,
        width: Int,
        height: Int,
        bands: Int
    ) throws {
        guard
            let image = vips_image_new_from_memory(
                buffer.baseAddress,
                buffer.count,
                .init(width),
                .init(height),
                .init(bands),
                .double
            )
        else {
            throw VIPSError()
        }

        self.init(image)
    }

    /// Creates a new image by loading the given data.
    ///
    /// The image will NOT copy the data into its own memory.
    /// You need to ensure that the data remains valid for the lifetime of the image and all its descendants.
    ///
    /// - Parameters:
    ///   - bufferNoCopy: The image data to load
    ///   - loader: The loader to use (optional)
    ///   - options: The options to use (optional)
    public convenience init(
        bufferNoCopy data: UnsafeRawBufferPointer,
        loader: String? = nil,
        options: String? = nil
    ) throws {

        func findLoader() throws -> String {
            guard let loader = vips_foreign_find_load_buffer(data.baseAddress, data.count) else {
                throw VIPSError()
            }
            return String(cString: loader)
        }

        let loader = try loader ?? findLoader()

        let blob = vips_blob_new(nil, data.baseAddress, data.count)
        defer {
            vips_area_unref(shim_vips_area(blob))
        }

        try self.init { out in
            var option = VIPSOption()
            option.set("buffer", value: blob)
            option.set("out", value: &out)
            try VIPSImage.call(loader, optionsString: options, options: &option)
        }
    }

    /// Creates a new image by loading the given data
    ///
    /// The image will copy the data into its own memory.
    ///
    /// - Parameters:
    ///   - data: The image data to load
    ///   - loader: The loader to use (optional)
    ///   - options: The options to use (optional)
    @inlinable
    public convenience init(
        data: some Collection<UInt8>,
        loader: String? = nil,
        options: String? = nil
    ) throws {
        guard
            let (loader, blob) = try data.withContiguousStorageIfAvailable({
                storage -> (String, UnsafeMutablePointer<VipsBlob>) in
                guard
                    let loader = loader
                        ?? vips_foreign_find_load_buffer(storage.baseAddress, storage.count)
                        .flatMap(String.init(cString:))
                else {
                    throw VIPSError()
                }

                return (loader, vips_blob_copy(storage.baseAddress, storage.count))
            })
        else {
            try self.init(data: Array(data), options: options)
            return
        }

        defer {
            vips_area_unref(shim_vips_area(blob))
        }

        try self.init { out in
            var option = VIPSOption()
            option.set("buffer", value: blob)
            option.set("out", value: &out)
            try VIPSImage.call(loader, optionsString: options, options: &option)
        }
    }

    /// Creates a new image by loading the given data
    ///
    /// The image will NOT copy the data into its own memory. You must
    /// ensure that the data remain valid for the lifetime of the image
    /// and all its descendants.
    ///
    /// - Parameters:
    ///   - unsafeData: The image data to load
    ///   - loader: The loader to use (optional)
    ///   - options: The options to use (optional)
    @inlinable
    public convenience init(
        unsafeData: UnsafeRawBufferPointer,
        loader: String? = nil,
        options: String? = nil
    ) throws {

        guard
            let loader = loader
                ?? vips_foreign_find_load_buffer(unsafeData.baseAddress, unsafeData.count)
                .flatMap(String.init(cString:))
        else {
            throw VIPSError()
        }

        let blob = vips_blob_new(nil, unsafeData.baseAddress, unsafeData.count)
        defer {
            vips_area_unref(shim_vips_area(blob))
        }

        try self.init { out in
            var option = VIPSOption()
            option.set("buffer", value: blob)
            option.set("out", value: &out)
            try VIPSImage.call(loader, optionsString: options, options: &option)
        }
    }

    /// Creates a new image by loading the given data
    ///
    /// The image will reference the data from the blob.
    ///
    /// - Parameters:
    ///   - blob: The image data to load
    ///   - loader: The loader to use (optional)
    ///   - options: The options to use (optional)
    @inlinable
    public convenience init(
        blob: VIPSBlob,
        loader: String? = nil,
        options: String? = nil
    ) throws {
        guard
            let loader = loader ?? blob.findLoader()
        else {
            throw VIPSError()
        }

        try self.init { out in
            var option = VIPSOption()
            try blob.withVipsBlob { blob in
                option.set("buffer", value: blob)
                option.set("out", value: &out)
                try VIPSImage.call(loader, optionsString: options, options: &option)
            }
        }
    }

    /// Creates a VIPSImage by loading from a file.
    ///
    /// Opens the specified file for reading. It can load files in many image formats,
    /// including VIPS, TIFF, PNG, JPEG, FITS, Matlab, OpenEXR, CSV, WebP, Radiance, RAW, PPM and others.
    ///
    /// Load options may be appended to the filename as `[name=value,...]`. Many loaders add extra options,
    /// see the individual loader documentation for details.
    ///
    /// This initializer always returns immediately with the header fields filled in. No pixels are
    /// actually read until you first access them.
    ///
    /// The `access` parameter lets you set an access hint giving the expected access pattern for this file:
    /// - `.random` means you can fetch pixels randomly from the image. This is the default mode.
    /// - `.sequential` means you will read the whole image exactly once, top-to-bottom. In this mode,
    ///   libvips can avoid converting the whole image in one go, for a large memory saving. You are
    ///   allowed to make small non-local references, so area operations like convolution will work.
    ///
    /// In `.random` mode, small images are decompressed to memory and then processed from there.
    /// Large images are decompressed to temporary random-access files on disc and then processed from there.
    ///
    /// Set `inMemory` to `true` to force loading via memory. The default is to load large random access
    /// images via temporary disc files. The disc threshold can be set with the `--vips-disc-threshold`
    /// command-line argument, or the `VIPS_DISC_THRESHOLD` environment variable. The default threshold is 100 MB.
    ///
    /// Examples:
    /// ```swift
    /// // Basic usage
    /// let image = try VIPSImage(fromFilePath: "fred.tif")
    ///
    /// // With access pattern hint
    /// let image = try VIPSImage(fromFilePath: "large.tif", access: .sequential)
    ///
    /// // Force memory loading
    /// let image = try VIPSImage(fromFilePath: "image.png", inMemory: true)
    ///
    /// // Load options can be embedded in filename
    /// let image = try VIPSImage(fromFilePath: "fred.jpg[shrink=2]")
    /// ```
    ///
    /// - Parameters:
    ///   - path: Path to the file to open
    ///   - access: Access pattern hint (`.random` or `.sequential`)
    ///   - inMemory: Force loading via memory instead of temporary files
    /// - Throws: VIPSError if the file cannot be opened or read
    public convenience init(fromFilePath path: String, access: VipsAccess = .random, inMemory: Bool = false)
        throws
    {
        guard let image = shim_vips_image_new_from_file(path, access, inMemory ? .true : .false)
        else {
            throw VIPSError(vips_error_buffer())
        }

        self.init(image)
    }

    public convenience init(
        fromSource source: VIPSSource,
        loader: String? = nil,
        options: String? = nil
    ) throws {

        let loader = try loader ?? source.findLoader()

        try self.init { out in
            var option = VIPSOption()
            option.set("source", value: source.source)
            option.set("out", value: &out)
            try VIPSImage.call(loader, optionsString: options, options: &option)
        }
    }

}

extension VIPSImageProtocol where Self: ~Copyable, Self: ~Escapable {

    @usableFromInline
    static func call(
        _ name: UnsafePointer<CChar>!,
        optionsString: String? = nil,
        options: inout VIPSOption
    ) throws {
        try self.call(String(cString: name), optionsString: optionsString, options: &options)
    }

    @usableFromInline
    static func call(_ name: String, optionsString: String? = nil, options: inout VIPSOption) throws
    {
        var op = try VIPSOperation(name: name)

        if let options = optionsString {
            try op.setFromString(options: options)
        }

        op.set(option: options)

        guard vips_cache_operation_buildp(&op.op) == 0 else {
            throw VIPSError()
        }

        op.get(option: &options)
    }
}

extension VIPSImageProtocol where Self: ~Copyable {
    @usableFromInline
    init(_ block: (inout UnsafeMutablePointer<VipsImage>?) throws -> Void) rethrows {
        let image: UnsafeMutablePointer<UnsafeMutablePointer<VipsImage>?> = .allocate(capacity: 1)
        image.initialize(to: nil)
        defer {
            image.deallocate()
        }
        try block(&image.pointee)
        precondition(image.pointee != nil, "Image pointer cannot be nil after init.")
        self.init(image.pointee!)
    }
}

extension VIPSImageProtocol where Self: ~Copyable {
    public func new(_ colors: [Double]) throws -> Self {
        try Self { out in
            var c = colors
            out = vips_image_new_from_image(self.image, &c, Int32(c.count))
            if out == nil { throw VIPSError() }
        }
    }

    /// Create a matrix image from a double array
    /// - Parameters:
    ///   - width: Width of the matrix
    ///   - height: Height of the matrix
    ///   - data: Array of doubles, must have width * height elements
    /// - Returns: A new VIPSImage matrix
    /// - Note: The data is copied by libvips, so the input array does not need to remain alive
    public static func matrix(width: Int, height: Int, data: [Double]) throws -> Self {
        guard data.count == width * height else {
            throw VIPSError(
                "Data array size (\(data.count)) must match width * height (\(width * height))"
            )
        }

        // libvips copies the data synchronously in vips_image_new_matrix_from_array,
        // so the pointer only needs to be valid for the duration of this call
        let image = data.withUnsafeBufferPointer { buffer in
            vips_image_new_matrix_from_array(
                Int32(width),
                Int32(height),
                buffer.baseAddress,
                Int32(data.count)
            )
        }

        guard let image else {
            throw VIPSError()
        }

        return Self(image)
    }

    /// Create an empty matrix image
    /// - Parameters:
    ///   - width: Width of the matrix
    ///   - height: Height of the matrix
    /// - Returns: A new VIPSImage matrix filled with zeros
    public static func matrix(width: Int, height: Int) throws -> Self {
        guard let image = vips_image_new_matrix(Int32(width), Int32(height)) else {
            throw VIPSError()
        }

        return Self(image)
    }

    /// This function allocates memory, renders image into it, builds a new image
    /// around the memory area, and returns that.
    ///
    /// If the image is already a simple area of memory, it just refs image and
    /// returns it.
    public func copyMemory() throws -> Self {
        return try Self { out in
            out = vips_image_copy_memory(self.image)
            if out == nil { throw VIPSError() }
        }
    }

}

public protocol VIPSImageProtocol: VIPSObjectProtocol, ~Escapable, ~Copyable {
    init(_ image: UnsafeMutablePointer<VipsImage>)
    var image: UnsafeMutablePointer<VipsImage>! { get }
}

extension VIPSImageProtocol where Self: ~Copyable, Self: ~Escapable {
    public func withVipsImage<R>(_ body: (UnsafeMutablePointer<VipsImage>) throws -> R) rethrows -> R {
        try body(self.image)
    }

    /// The number of pixels across the image.
    @inlinable
    public var width: Int {
        return Int(vips_image_get_width(self.image))
    }

    /// The number of pixels down the image.
    @inlinable
    public var height: Int {
        return Int(vips_image_get_height(self.image))
    }

    /// The number of bands (channels) in the image.
    @inlinable
    public var bands: Int {
        return Int(vips_image_get_bands(self.image))
    }

    /// The kill flag for this image.
    ///
    /// When getting: If the image has been killed, returns `true`. Otherwise returns `false`.
    ///
    /// When setting: Set the kill flag on an image. Setting this to `true` will block eval
    /// and is handy for stopping sets of threads.
    ///
    /// - SeeAlso: `setProgressReportingEnabled(_:)`
    public var kill: Bool {
        get {
            return vips_image_iskilled(self.image) != 0
        }
        nonmutating set {
            vips_image_set_kill(self.image, newValue ? 1 : 0)
        }

    }

    /// Enable or disable progress reporting for this image.
    ///
    /// VIPS signals evaluation progress via the `preeval`, `eval` and `posteval` signals.
    /// Progress is signalled on the most-downstream image for which `setProgressReportingEnabled(_:)`
    /// was called with `true`.
    ///
    /// - Parameter enabled: `true` to enable progress reporting, `false` to disable
    ///
    /// - SeeAlso: `onPreeval(_:)`, `onEval(_:)`, `onPosteval(_:)`
    public func setProgressReportingEnabled(_ enabled: Bool) {
        vips_image_set_progress(self.image, enabled ? .true : .false)
    }

    /// Connect a handler to be called when evaluation is starting.
    ///
    /// This signal is emitted when image evaluation begins. The handler receives
    /// the image reference and a `VIPSProgress` struct with evaluation information.
    ///
    /// - Parameter handler: Closure to be called when evaluation starts
    /// - Returns: Signal handler ID that can be used to disconnect the handler
    ///
    /// - SeeAlso: `setProgressReportingEnabled(_:)`, `onEval(_:)`, `onPosteval(_:)`
    @discardableResult
    public func onPreeval(_ handler: @escaping (UnownedVIPSImageRef, VIPSProgress) -> Void) -> Int {
        self.onProgress(signal: "preeval", handler: handler)
    }

    /// Connect a handler to be called during evaluation progress.
    ///
    /// This signal is emitted periodically during image evaluation to report progress.
    /// The handler receives the image reference and a `VIPSProgress` struct with
    /// current evaluation information including percent complete.
    ///
    /// - Parameter handler: Closure to be called during evaluation
    /// - Returns: Signal handler ID that can be used to disconnect the handler
    ///
    /// - SeeAlso: `setProgressReportingEnabled(_:)`, `onPreeval(_:)`, `onPosteval(_:)`
    @discardableResult
    public func onEval(_ handler: @escaping (UnownedVIPSImageRef, VIPSProgress) -> Void) -> Int {
        self.onProgress(signal: "eval", handler: handler)
    }

    /// Connect a handler to be called when evaluation is ending.
    ///
    /// This signal is emitted when image evaluation completes. The handler receives
    /// the image reference and a `VIPSProgress` struct with final evaluation information.
    ///
    /// - Parameter handler: Closure to be called when evaluation ends
    /// - Returns: Signal handler ID that can be used to disconnect the handler
    ///
    /// - SeeAlso: `setProgressReportingEnabled(_:)`, `onPreeval(_:)`, `onEval(_:)`
    @discardableResult
    public func onPosteval(_ handler: @escaping (UnownedVIPSImageRef, VIPSProgress) -> Void) -> Int {
        self.onProgress(signal: "posteval", handler: handler)
    }

    private func onProgress(signal: String, handler: @escaping (UnownedVIPSImageRef, VIPSProgress) -> Void)
        -> Int
    {
        let cHandler:
            @convention(c) (
                UnsafeMutablePointer<VipsImage>?, UnsafeMutablePointer<VipsProgress>?,
                UnsafeMutableRawPointer?
            ) -> Void = { imagePtr, progressPtr, userData in
                guard
                    let imagePtr,
                    let progressPtr,
                    let userData
                else {
                    return
                }

                let holder = Unmanaged<
                    ClosureHolder<(UnownedVIPSImageRef, VIPSProgress), Void>
                >
                .fromOpaque(userData).takeUnretainedValue()
                holder.closure((UnownedVIPSImageRef(imagePtr), progressPtr.pointee))
            }
        let closureHolder = ClosureHolder<(UnownedVIPSImageRef, VIPSProgress), Void>(handler)
        let userData = Unmanaged.passRetained(closureHolder).toOpaque()

        return self.connect(
            signal: signal,
            callback: unsafeBitCast(cHandler, to: GCallback.self),
            userData: userData,
            destroyData: { userData, _ in
                if let userData {
                    Unmanaged<
                        ClosureHolder<(UnownedVIPSImageRef, VIPSProgress), Void>
                    >
                    .fromOpaque(userData)
                    .release()
                }
            }
        )
    }
}

public struct UnownedVIPSImageRef: VIPSImageProtocol, ~Escapable {
    public var ptr: UnsafeMutableRawPointer!

    public init(_ image: UnsafeMutablePointer<VipsImage>) {
        self.ptr = UnsafeMutableRawPointer(image)
    }

    public init(_ ptr: UnsafeMutableRawPointer) {
        self.ptr = ptr
    }

    public var image: UnsafeMutablePointer<VipsImage>! {
        return ptr.assumingMemoryBound(to: VipsImage.self)
    }
}

extension VIPSImage {
    public convenience init(takingOwnership imgRef: UnownedVIPSImageRef) {
        self.init(g_object_ref(imgRef.ptr))
    }
}