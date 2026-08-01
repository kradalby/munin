## Module `VIPS`

### Table of Contents

| Type | Name |
| --- | --- |
| class | `VIPSObject` |
| class | `VIPSBlob` |
| class | `VIPSImage` |
| struct | `VIPSImage.Size` |
| class | `VIPSInterpolate` |
| class | `VIPSTarget` |
| class | `VIPSTargetCustom` |
| struct | `UnownedVIPSImageRef` |
| struct | `UnownedVIPSObjectRef` |
| struct | `VIPSError` |
| struct | `VIPSObjectRef` |
| struct | `VIPSOption` |
| struct | `Whence` |
| enum | `VIPS` |
| protocol | `PointerWrapper` |
| protocol | `VIPSImageProtocol` |
| protocol | `VIPSLoggingDelegate` |
| protocol | `VIPSObjectProtocol` |
| func | `vipsFindLoader(path:)` |
| typealias | `VIPSProgress` |
| typealias | `VipsAccess` |
| typealias | `VipsAlign` |
| typealias | `VipsAngle` |
| typealias | `VipsAngle45` |
| typealias | `VipsArgumentFlags` |
| typealias | `VipsBandFormat` |
| typealias | `VipsBlendMode` |
| typealias | `VipsCoding` |
| typealias | `VipsCombine` |
| typealias | `VipsCombineMode` |
| typealias | `VipsCompassDirection` |
| typealias | `VipsDemandStyle` |
| typealias | `VipsDirection` |
| typealias | `VipsExtend` |
| typealias | `VipsFailOn` |
| typealias | `VipsForeignFlags` |
| typealias | `VipsForeignKeep` |
| typealias | `VipsForeignSubsample` |
| typealias | `VipsImageType` |
| typealias | `VipsIntent` |
| typealias | `VipsInteresting` |
| typealias | `VipsInterpretation` |
| typealias | `VipsKernel` |
| typealias | `VipsOperationBoolean` |
| typealias | `VipsOperationComplex` |
| typealias | `VipsOperationComplex2` |
| typealias | `VipsOperationComplexget` |
| typealias | `VipsOperationFlags` |
| typealias | `VipsOperationMath` |
| typealias | `VipsOperationMath2` |
| typealias | `VipsOperationMorphology` |
| typealias | `VipsOperationRelational` |
| typealias | `VipsOperationRound` |
| typealias | `VipsPCS` |
| typealias | `VipsPrecision` |
| typealias | `VipsRegionShrink` |
| typealias | `VipsSize` |
| typealias | `VipsTextWrap` |
| Array extension | `Array` |
| Collection extension | `Collection` |

### Public interface

#### class VIPSObject

```swift
public class VIPSObject: PointerWrapper, VIPSObjectProtocol {
  public var ptr: UnsafeMutableRawPointer!

  public var type: GType { get }

  public required init(_ ptr: UnsafeMutableRawPointer)
}
```

#### class VIPSBlob

```swift
public final class VIPSBlob: Collection, ExpressibleByArrayLiteral, Sendable, SendableMetatype, Sequence {
  /// The number of elements in the collection.
  /// 
  /// To check whether a collection is empty, use its `isEmpty` property
  /// instead of comparing `count` to zero. Unless the collection guarantees
  /// random-access performance, calculating `count` can be an O(*n*)
  /// operation.
  /// 
  /// - Complexity: O(1) if the collection conforms to
  ///   `RandomAccessCollection`; otherwise, O(*n*), where *n* is the length
  ///   of the collection.
  public var count: Int { get }

  /// A textual representation of this instance, suitable for debugging.
  /// 
  /// Calling this property directly is discouraged. Instead, convert an
  /// instance of any type to a string by using the `String(reflecting:)`
  /// initializer. This initializer works with any type, and uses the custom
  /// `debugDescription` property for types that conform to
  /// `CustomDebugStringConvertible`:
  /// 
  ///     struct Point: CustomDebugStringConvertible {
  ///         let x: Int, y: Int
  /// 
  ///         var debugDescription: String {
  ///             return "(\(x), \(y))"
  ///         }
  ///     }
  /// 
  ///     let p = Point(x: 21, y: 30)
  ///     let s = String(reflecting: p)
  ///     print(s)
  ///     // Prints "(21, 30)"
  /// 
  /// The conversion of `p` to a string in the assignment to `s` uses the
  /// `Point` type's `debugDescription` property.
  public var debugDescription: String { get }

  /// The collection's "past the end" position---that is, the position one
  /// greater than the last valid subscript argument.
  /// 
  /// When you need a range that includes the last element of a collection, use
  /// the half-open range operator (`..<`) with `endIndex`. The `..<` operator
  /// creates a range that doesn't include the upper bound, so it's always
  /// safe to use with `endIndex`. For example:
  /// 
  ///     let numbers = [10, 20, 30, 40, 50]
  ///     if let index = numbers.firstIndex(of: 30) {
  ///         print(numbers[index ..< numbers.endIndex])
  ///     }
  ///     // Prints "[30, 40, 50]"
  /// 
  /// If the collection is empty, `endIndex` is equal to `startIndex`.
  public var endIndex: Int { get }

  /// The position of the first element in a nonempty collection.
  /// 
  /// If the collection is empty, `startIndex` is equal to `endIndex`.
  public var startIndex: Int { get }

  public func copy() -> VIPSBlob

  public func findLoader() -> String?

  /// Returns the position immediately after the given index.
  /// 
  /// The successor of an index must be well defined. For an index `i` into a
  /// collection `c`, calling `c.index(after: i)` returns the same index every
  /// time.
  /// 
  /// - Parameter i: A valid index of the collection. `i` must be less than
  ///   `endIndex`.
  /// - Returns: The index value immediately after `i`.
  public func index(after i: Int) -> Int

  /// Creates a new VIPSBlob by copying the bytes from the given collection.
  public init(_ buffer: some Collection<UInt8>)

  /// Creates an instance initialized with the given elements.
  public convenience init(arrayLiteral elements: UInt8...)

  /// Create a VIPSBlob from a buffer without copying the data.
  /// IMPORTANT: It is the responsibility of the caller to ensure that the buffer remains valid for the lifetime
  /// of the VIPSBlob or any derived images.
  public init(noCopy buffer: UnsafeRawBufferPointer)

  /// Create a VIPSBlob from a buffer without copying the data.
  /// Will call `onDealloc` when the lifetime of the blob ends.
  /// IMPORTANT: It is the responsibility of the caller to ensure that the buffer remains valid for the lifetime
  /// of the VIPSBlob or any derived images.
  public init(noCopy buffer: UnsafeRawBufferPointer, onDealloc: @escaping () -> Void)

  /// Yield the contiguous buffer of this blob.
  /// 
  /// Never returns nil, unless `body` returns nil.
  public func withContiguousStorageIfAvailable<R>(_ body: (UnsafeBufferPointer<UInt8>) throws -> R) rethrows -> R?

  public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R

  /// Access the raw bytes of the blob.
  /// 
  /// If you escape the pointer from the closure, you _must_ call `storageManagement.retain()` to get ownership to
  /// the bytes and you also must call `storageManagement.release()` if you no longer require those bytes. Calls to
  /// `retain` and `release` must be balanced.
  public func withUnsafeBytesAndStorageManagement<R>(_ body: (UnsafeRawBufferPointer, Unmanaged<AnyObject>) throws -> R) rethrows -> R
}
```

#### class VIPSImage

```swift
public final class VIPSImage: PointerWrapper, VIPSImageProtocol, VIPSObjectProtocol {
  /// A structure representing the dimensions of an image.
  public struct Size {
    /// The height of the image in pixels.
    public var height: Int

    /// The width of the image in pixels.
    public var width: Int

    /// Creates a new Size with the specified width and height.
    public init(width: Int, height: Int)
  }

  /// The number of bands (channels) in the image.
  /// 
  /// For example, RGB images have 3 bands, RGBA images have 4 bands,
  /// and grayscale images have 1 band.
  /// - Returns: The number of bands in the image
  public var bands: Int { get }

  /// The name of the file the image was loaded from.
  /// 
  /// Returns the filename that was used to load this image, or `nil`
  /// if the image was created programmatically or from memory.
  /// - Returns: The filename, or `nil` if no filename is available
  public var filename: String? { get }

  /// Whether the image has an alpha channel.
  /// 
  /// This checks if the image has transparency information. For example,
  /// RGBA images return true, while RGB images return false.
  /// - Returns: `true` if the image has an alpha channel, `false` otherwise
  public var hasAlpha: Bool { get }

  /// Whether the image has an embedded ICC color profile.
  /// 
  /// ICC profiles contain information about the color characteristics
  /// of the image and are used for accurate color reproduction.
  /// - Returns: `true` if the image has an ICC profile, `false` otherwise
  public var hasProfile: Bool { get }

  /// The number of pixels down the image.
  /// - Returns: The image height in pixels
  public var height: Int { get }

  /// The processing history of the image.
  /// 
  /// VIPS maintains a log of operations that have been performed on an image.
  /// This can be useful for debugging or understanding how an image was created.
  /// - Returns: The history string, or `nil` if no history is available
  public var history: String? { get }

  /// The image mode as a string.
  /// 
  /// This is an optional string field that can be used to store additional
  /// information about how the image should be interpreted or processed.
  /// - Returns: The mode string, or `nil` if no mode is set
  public var mode: String? { get }

  /// The number of pages in the image file.
  /// 
  /// This is the number of pages in the original image file, not necessarily
  /// the number of pages that have been loaded into this image object.
  /// For single-page images, this returns 1.
  /// - Returns: The number of pages in the image file
  public var nPages: Int { get }

  /// The number of sub-image file directories.
  /// 
  /// Some image formats (particularly TIFF) can contain multiple sub-images
  /// or sub-directories. This returns the count of such structures.
  /// Returns 0 if not present or not applicable to the format.
  /// - Returns: The number of sub-IFDs in the image file
  public var nSubifds: Int { get }

  /// The offset value for matrix images.
  /// 
  /// Matrix images can have an optional offset field for use by integer
  /// convolution operations. The offset is added after convolution
  /// and scaling.
  /// - Returns: The offset value, typically 0.0 for non-matrix images
  public var offset: Double { get }

  /// The EXIF orientation value for the image.
  /// 
  /// Returns the orientation value from EXIF metadata, if present.
  /// Values range from 1-8 according to the EXIF specification.
  /// - Returns: The EXIF orientation value, or 1 if no orientation is set
  public var orientation: Int { get }

  /// Whether applying the orientation would swap width and height.
  /// 
  /// Some EXIF orientations require rotating the image by 90 or 270 degrees,
  /// which would swap the width and height dimensions. This property
  /// indicates if such a swap would occur.
  /// - Returns: `true` if width and height would swap when applying orientation
  public var orientationSwap: Bool { get }

  /// The height of each page in multi-page images.
  /// 
  /// Multi-page images (such as animated GIFs or multi-page TIFFs) can have
  /// a page height different from the total image height. If page-height is
  /// not set, it defaults to the image height.
  /// - Returns: The height of each page in pixels
  public var pageHeight: Int { get }

  public var ptr: UnsafeMutableRawPointer!

  /// The scale factor for matrix images.
  /// 
  /// Matrix images can have an optional scale field for use by integer
  /// convolution operations. The scale is applied after convolution
  /// to normalize the result.
  /// - Returns: The scale factor, typically 1.0 for non-matrix images
  public var scale: Double { get }

  /// The size of the image as a Size struct containing width and height.
  /// - Returns: A Size struct with the image dimensions in pixels
  public var size: Size { get }

  /// The interpretation of the image as a human-readable string.
  /// 
  /// This returns the string representation of the image's interpretation,
  /// such as "srgb", "rgb", "cmyk", "lab", etc.
  /// - Returns: A string describing the image interpretation
  public var space: String { get }

  /// The number of pixels across the image.
  /// - Returns: The image width in pixels
  public var width: Int { get }

  /// The horizontal position of the image origin, in pixels.
  /// 
  /// This is a hint about where this image should be positioned relative
  /// to some larger canvas. It's often used in image tiling operations.
  /// - Returns: The horizontal offset in pixels
  public var xoffset: Int { get }

  /// The horizontal image resolution in pixels per millimeter.
  /// 
  /// This represents the physical resolution of the image when printed
  /// or displayed. A value of 1.0 means 1 pixel per millimeter.
  /// - Returns: The horizontal resolution in pixels per millimeter
  public var xres: Double { get }

  /// The vertical position of the image origin, in pixels.
  /// 
  /// This is a hint about where this image should be positioned relative
  /// to some larger canvas. It's often used in image tiling operations.
  /// - Returns: The vertical offset in pixels
  public var yoffset: Int { get }

  /// The vertical image resolution in pixels per millimeter.
  /// 
  /// This represents the physical resolution of the image when printed
  /// or displayed. A value of 1.0 means 1 pixel per millimeter.
  /// - Returns: The vertical resolution in pixels per millimeter
  public var yres: Double { get }

  /// Calculate arccosine of image values (result in degrees)
  public func acos() throws -> VIPSImage

  /// Calculate inverse hyperbolic cosine of image values
  public func acosh() throws -> VIPSImage

  /// Bitwise AND of image with a constant (integer overload)
  public func andimage(_ value: Int) throws -> VIPSImage

  /// Calculate arcsine of image values (result in degrees)
  public func asin() throws -> VIPSImage

  /// Calculate inverse hyperbolic sine of image values
  public func asinh() throws -> VIPSImage

  /// Calculate arctangent of image values (result in degrees)
  public func atan() throws -> VIPSImage

  /// Calculate two-argument arctangent of y/x in degrees
  public func atan2(_ x: VIPSImage) throws -> VIPSImage

  /// Calculate inverse hyperbolic tangent of image values
  public func atanh() throws -> VIPSImage

  /// Same as `autorot()`
  /// 
  /// See: `VIPSImage.autorot()`
  public func autorotate() throws -> VIPSImage

  /// Perform bitwise AND operation across bands.
  /// 
  /// Reduces multiple bands to a single band by performing bitwise AND
  /// on corresponding pixels across all bands.
  /// 
  /// - Returns: A new single-band image
  /// - Throws: `VIPSError` if the operation fails
  public func bandand() throws -> VIPSImage

  /// Perform bitwise XOR (exclusive OR) operation across bands.
  /// 
  /// Reduces multiple bands to a single band by performing bitwise XOR
  /// on corresponding pixels across all bands.
  /// 
  /// - Returns: A new single-band image
  /// - Throws: `VIPSError` if the operation fails
  public func bandeor() throws -> VIPSImage

  /// See VIPSImage.bandjoin(`in`:)
  public func bandjoin(_ other: [VIPSImage]) throws -> VIPSImage

  /// Perform bitwise OR operation across bands.
  /// 
  /// Reduces multiple bands to a single band by performing bitwise OR
  /// on corresponding pixels across all bands.
  /// 
  /// - Returns: A new single-band image
  /// - Throws: `VIPSError` if the operation fails
  public func bandor() throws -> VIPSImage

  public func ceil() throws -> VIPSImage

  /// Create a complex image from real and imaginary parts
  public func complex(_ imaginary: VIPSImage) throws -> VIPSImage

  /// Get the concurrency hint for this image.
  /// 
  /// This returns the suggested level of parallelism for operations on this
  /// image. It can be used to optimize performance by limiting the number
  /// of threads used for processing.
  /// 
  /// - Parameter defaultConcurrency: The default value to return if no hint is set
  /// - Returns: The suggested concurrency level
  public func concurrency(default defaultConcurrency: Int = 1) -> Int

  /// Calculate complex conjugate
  public func conj() throws -> VIPSImage

  /// Calculate cosine of image values (in degrees)
  public func cos() throws -> VIPSImage

  /// Calculate hyperbolic cosine of image values
  public func cosh() throws -> VIPSImage

  /// Alias for extractArea - crop an image
  public func crop(left: Int, top: Int, width: Int, height: Int) throws -> VIPSImage

  /// Bitwise XOR of image with a constant (integer overload)
  public func eorimage(_ value: Int) throws -> VIPSImage

  /// Calculate e^x for each pixel
  public func exp() throws -> VIPSImage

  /// Calculate 10^x for each pixel
  public func exp10() throws -> VIPSImage

  public func floor() throws -> VIPSImage

  /// Get the value of the pixel at the specified coordinates.
  /// 
  /// This is a convenience method that calls the main `getpoint` implementation.
  /// The pixel value is returned as an array of doubles, with one element
  /// per band in the image.
  /// 
  public func getpoint(_ x: Int, _ y: Int) throws -> [Double]

  /// Extract imaginary part of complex image
  public func imag() throws -> VIPSImage

  public init(_ ptr: UnsafeMutableRawPointer)

  /// Creates a new image by loading the given data
  /// 
  /// The image will reference the data from the blob.
  /// 
  public convenience init(blob: VIPSBlob, loader: String? = nil, options: String? = nil) throws

  /// Creates a new image by loading the given data.
  /// 
  /// The image will NOT copy the data into its own memory.
  /// You need to ensure that the data remains valid for the lifetime of the image and all its descendants.
  /// 
  public convenience init(bufferNoCopy data: UnsafeRawBufferPointer, loader: String? = nil, options: String? = nil) throws

  /// Creates a new image by loading the given data
  /// 
  /// The image will copy the data into its own memory.
  /// 
  public convenience init(data: some Collection<UInt8>, loader: String? = nil, options: String? = nil) throws

  /// Creates a VIPSImage from 64-bit floating point data with memory copy.
  /// 
  /// This function creates a VipsImage from a memory area. The memory area must be a simple array,
  /// for example RGBRGBRGB, left-to-right, top-to-bottom. The memory will be copied into the image.
  /// 
  public convenience init(data: some Collection<Double>, width: Int, height: Int, bands: Int) throws

  public convenience init(takingOwnership imgRef: UnownedVIPSImageRef)

  /// Creates a new image by loading the given data
  /// 
  /// The image will NOT copy the data into its own memory. You must
  /// ensure that the data remain valid for the lifetime of the image
  /// and all its descendants.
  /// 
  public convenience init(unsafeData: UnsafeRawBufferPointer, loader: String? = nil, options: String? = nil) throws

  /// Creates a VIPSImage from a memory area containing 64-bit floating point data.
  /// 
  /// This function wraps a VipsImage around a memory area. The memory area must be a simple array,
  /// for example RGBRGBRGB, left-to-right, top-to-bottom.
  /// 
  /// **DANGER**: VIPS does not take responsibility for the memory area. The memory will NOT be copied
  /// into the image. You must ensure the memory remains valid for the lifetime of the image and all
  /// its descendants. Use the copy variant if you are unsure about memory management.
  /// 
  public convenience init(unsafeData buffer: UnsafeBufferPointer<Double>, width: Int, height: Int, bands: Int) throws

  public func linear(_ a: [Double], _ b: [Double], uchar: Bool? = nil) throws -> VIPSImage

  /// Calculate natural logarithm (ln) of each pixel
  public func log() throws -> VIPSImage

  /// Calculate base-10 logarithm of each pixel
  public func log10() throws -> VIPSImage

  /// Left shift with an image of shift amounts
  public func lshift(_ shiftAmounts: VIPSImage) throws -> VIPSImage

  /// Bitwise OR of image with a constant (integer overload)
  public func orimage(_ value: Int) throws -> VIPSImage

  /// Convert complex image to polar form
  public func polar() throws -> VIPSImage

  /// Raise image values to a constant power (integer overload)
  public func pow(_ exponent: Int) throws -> VIPSImage

  /// Extract profiles from an image.
  /// 
  /// Creates 1D profiles by averaging across rows and columns.
  /// Returns two images: column profile (vertical average) and row profile (horizontal average).
  /// 
  /// - Returns: A tuple containing (columns profile, rows profile)
  /// - Throws: `VIPSError` if the operation fails
  public func profile() throws -> (columns: VIPSImage, rows: VIPSImage)

  /// Project rows and columns to get sums.
  /// 
  /// Returns two 1D images containing the sum of each row and column.
  /// Useful for creating projections and histograms.
  /// 
  /// - Returns: A tuple containing (row sums, column sums)
  /// - Throws: `VIPSError` if the operation fails
  public func project() throws -> (rows: VIPSImage, columns: VIPSImage)

  /// Extract real part of complex image
  public func real() throws -> VIPSImage

  /// Convert polar image to rectangular form
  public func rect() throws -> VIPSImage

  public func round() throws -> VIPSImage

  /// Right shift with an image of shift amounts  
  public func rshift(_ shiftAmounts: VIPSImage) throws -> VIPSImage

  /// Calculate sine of image values (in degrees)
  public func sin() throws -> VIPSImage

  /// Calculate hyperbolic sine of image values
  public func sinh() throws -> VIPSImage

  /// Calculate tangent of image values (in degrees)
  public func tan() throws -> VIPSImage

  /// Calculate hyperbolic tangent of image values
  public func tanh() throws -> VIPSImage

  /// Raise a constant to the power of this image (integer overload)
  public func wop(_ base: Int) throws -> VIPSImage

  /// Writes the image to a memory buffer in the specified format.
  /// 
  /// This method writes the image to a memory buffer using a format determined by the suffix.
  /// Save options may be appended to the suffix as `[name=value,...]` or given in the params
  /// dictionary. Options given in the function call override options given in the filename.
  /// 
  /// Currently TIFF, JPEG, PNG and other formats are supported depending on your libvips build.
  /// You can call the various save operations directly if you wish, see `jpegsave(buffer:)` for example.
  /// 
  public func writeToBuffer(suffix: String, quality: Int? = nil, options params: [String : Any] = [:], additionalOptions: String? = nil) throws -> VIPSBlob

  /// Writes the image to a file.
  /// 
  /// This method writes the image to a file using the saver recommended by the filename extension.
  /// Save options may be appended to the filename as `[name=value,...]` or given in the options
  /// dictionary. Options given in the function call override options given in the filename.
  /// 
  public func writeToFile(_ path: String, quality: Int? = nil, options: [String : Any] = [:], additionalOptions: String? = nil) throws

  /// Writes the image to a target in the specified format.
  /// 
  /// This method writes the image to a target using a format determined by the suffix.
  /// Save options may be appended to the suffix as `[name=value,...]` or given in the params
  /// dictionary. Options given in the function call override options given in the filename.
  /// 
  /// You can call the various save operations directly if you wish, see `jpegsave(target:)` for example.
  /// 
  public func writeToTarget(suffix: String, target: VIPSTarget, quality: Int? = nil, options params: [String : Any] = [:], additionalOptions: String? = nil) throws
}
```

#### class VIPSInterpolate

```swift
public class VIPSInterpolate: VIPSObject, PointerWrapper, VIPSObjectProtocol {
  public var bilinear: VIPSInterpolate { get }

  public var nearest: VIPSInterpolate { get }

  public init(_ name: String) throws
}
```

#### class VIPSTarget

```swift
/// A VIPSTarget represents a data destination for saving images in libvips.
/// 
/// Targets can write to various destinations including files, memory buffers,
/// file descriptors, and custom writers. Targets support both seekable
/// operations (for files and memory) and streaming operations (for pipes and
/// network connections).
/// 
/// # Target Types
/// 
/// Different target types have different capabilities:
/// - **File targets**: Support seeking and random access for formats that require it (like TIFF)
/// - **Memory targets**: Store output in memory, accessible via steal() methods
/// - **Pipe targets**: Support only sequential writing, suitable for streaming
/// - **Custom targets**: Behavior depends on the custom implementation
/// 
/// # Usage Patterns
/// 
/// ```swift
/// // Save to file
/// let target = try VIPSTarget(toFile: "/path/to/output.jpg")
/// try image.write(to: target)
/// 
/// // Save to memory
/// let target = try VIPSTarget(toMemory: ())
/// try image.write(to: target)
/// let data = try target.steal()
/// 
/// // Custom target with callback
/// let customTarget = VIPSTargetCustom()
/// customTarget.onWrite { bytes in
///     // Process the written bytes
///     return bytes.count  // Return bytes processed
/// }
/// ```
/// 
/// # Thread Safety
/// 
/// VIPSTarget instances are not thread-safe. Each target should be used
/// from a single thread, or access should be synchronized externally.
public class VIPSTarget: VIPSObject, PointerWrapper, VIPSObjectProtocol {
  /// Returns true if the target has been ended.
  /// 
  /// Once a target is ended, no further write operations should be performed.
  /// This is set to true after calling end().
  public var isEnded: Bool { get }

  /// Returns true if this is a memory target.
  /// 
  /// Memory targets accumulate written data in an internal buffer
  /// that can be retrieved with steal() methods.
  public var isMemory: Bool { get }

  /// Creates a target that writes to memory.
  /// 
  /// Data written to this target is accumulated in an internal buffer.
  /// Use steal() or stealText() to retrieve the accumulated data.
  /// 
  /// - Throws: VIPSError if the target cannot be created
  public static func toMemory() throws -> VIPSTarget

  /// Ends the target and flushes all remaining data.
  /// 
  /// This finalizes the target, ensuring all buffered data is written
  /// and any cleanup is performed. After calling this method, no further
  /// write operations should be performed on this target.
  /// 
  /// Note: This replaces the deprecated finish() method.
  /// 
  /// - Throws: VIPSError if the end operation fails
  public func end() throws

  public required init(_ ptr: UnsafeMutableRawPointer)

  /// Creates a temporary target based on another target.
  /// 
  /// This creates a temporary target that can be used for intermediate
  /// operations before writing to the final target.
  /// 
  /// - Parameter basedOn: The target to base the temporary target on
  /// - Throws: VIPSError if the target cannot be created
  public init(temp basedOn: VIPSTarget) throws

  /// Creates a target from a file descriptor.
  /// 
  /// The file descriptor is not closed when the target is destroyed.
  /// The caller is responsible for managing the file descriptor's lifecycle.
  /// 
  /// - Parameter descriptor: An open file descriptor to write to
  /// - Throws: VIPSError if the target cannot be created
  public init(toDescriptor descriptor: Int32) throws

  /// Creates a target that will write to the named file.
  /// 
  /// The file is created immediately. If the file already exists, it will be
  /// truncated. The directory containing the file must exist.
  /// 
  /// - Parameter path: Path to the file to write to
  /// - Throws: VIPSError if the target cannot be created
  public init(toFile path: String) throws

  /// Writes a single character to the target.
  /// 
  /// - Parameter character: The character to write (as an ASCII value)
  /// - Throws: VIPSError if the write operation fails
  public func putc(_ character: Int) throws

  public func read(into span: inout OutputRawSpan) throws

  /// Changes the current position within the target.
  /// 
  /// This operation is only supported on seekable targets (like files).
  /// Some formats (like TIFF) require the ability to seek within the target.
  /// 
  /// The whence parameter determines how the offset is interpreted:
  /// - SEEK_SET (0): Absolute position from start
  /// - SEEK_CUR (1): Relative to current position
  /// - SEEK_END (2): Relative to end of target
  /// 
  public @discardableResult func seek(offset: Int64, whence: Whence) throws -> Int64

  /// Sets the current position to an absolute position from the start.
  /// 
  /// This is a convenience wrapper for seek(offset:whence:) with SEEK_SET.
  /// 
  /// - Parameter position: The absolute position from the start
  /// - Returns: The new position (should equal the input position)
  /// - Throws: VIPSError if seeking fails or is not supported
  public @discardableResult func setPosition(_ position: Int64) throws -> Int64

  /// Steals the accumulated data from a memory target.
  /// 
  /// This extracts all data that has been written to the target.
  /// This can only be used on memory targets created with init(toMemory:).
  /// The target should be ended before calling this method.
  /// 
  /// - Returns: Array containing all the written bytes
  /// - Throws: VIPSError if the target is not a memory target or steal fails
  public func steal() throws -> [UInt8]

  /// Steals the accumulated data from a memory target.
  /// 
  /// This extracts all data that has been written to the target.
  /// This can only be used on memory targets created with init(toMemory:).
  /// The target should be ended before calling this method.
  /// 
  /// - Parameter work: Closure that receives the stolen data buffer. The buffer
  ///             may not escape the closure.
  /// - Returns: The result of the work closure
  /// - Throws: VIPSError if the target is not a memory target or steal fails
  public func steal<Result>(_ work: (UnsafeRawBufferPointer) throws -> Result) throws -> Result

  /// Steals the accumulated data as a UTF-8 string from a memory target.
  /// 
  /// This extracts all data that has been written to the target and
  /// interprets it as a UTF-8 string. This can only be used on memory
  /// targets created with init(toMemory:). The target should be ended
  /// before calling this method.
  /// 
  /// - Returns: String containing all the written data
  /// - Throws: VIPSError if the target is not a memory target or steal fails
  public func stealText() throws -> String

  /// Reads data from the target into the provided buffer.
  /// 
  /// This operation is only supported on seekable targets (like files).
  /// Some formats (like TIFF) require the ability to read back data
  /// that has been written.
  /// 
  /// - Parameter buffer: Buffer to read data into
  /// - Returns: Number of bytes actually read
  /// - Throws: VIPSError if the read operation fails or is not supported
  public @discardableResult func unsafeRead(into buffer: UnsafeMutableRawBufferPointer) throws -> Int

  /// Writes raw data from a pointer to the target.
  /// 
  /// This allows writing data from unsafe pointers without copying.
  /// The memory must remain valid for the duration of the call.
  /// 
  public @discardableResult func write(_ data: UnsafeRawBufferPointer) throws -> Int

  /// Writes a string with XML-style entity encoding.
  /// 
  /// This writes a string while encoding XML entities like &, <, >, etc.
  /// This is useful when writing XML or HTML content.
  /// 
  /// - Parameter string: The string to write with entity encoding
  /// - Throws: VIPSError if the write operation fails
  public func writeAmp(_ string: String) throws

  /// Writes a string to the target.
  /// 
  /// The string is written as UTF-8 encoded bytes without a null terminator.
  /// 
  /// - Parameter string: The string to write
  /// - Throws: VIPSError if the write operation fails
  public func writes(_ string: String) throws
}
```

#### class VIPSTargetCustom

```swift
/// A custom VIPSTarget that allows you to implement your own write behavior.
/// 
/// This class provides a way to create targets with custom write, seek, and
/// read implementations. You can use this to write to custom destinations
/// like network streams, compressed files, or any other custom storage.
/// 
/// # Usage Example
/// 
/// ```swift
/// let customTarget = VIPSTargetCustom()
/// 
/// // Set up write handler
/// customTarget.onWrite { bytes in
///     // Write bytes to your custom destination
///     // Return the number of bytes actually written
///     return writeToCustomDestination(bytes)
/// }
/// 
/// // Set up end handler (replaces deprecated finish)
/// customTarget.onEnd {
///     // Finalize your custom destination
///     finalizeCustomDestination()
///     return 0  // 0 for success
/// }
/// 
/// // For seekable custom targets, also implement:
/// customTarget.onSeek { offset, whence in
///     return seekInCustomDestination(offset, whence)
/// }
/// 
/// customTarget.onRead { length in
///     return readFromCustomDestination(length)
/// }
/// ```
/// 
/// # Callback Requirements
/// 
/// - **Write callback**: Must consume as many bytes as possible and return the actual count
/// - **End callback**: Should finalize the destination and release resources
/// - **Seek callback**: Should change position and return new absolute position (-1 for error)
/// - **Read callback**: Should read up to the requested bytes and return actual data read
public final class VIPSTargetCustom: VIPSTarget, PointerWrapper, VIPSObjectProtocol {
  /// Creates a new custom target with default (no-op) implementations.
  /// 
  /// After creation, set up the appropriate callback handlers using
  /// onWrite(), onEnd(), onSeek(), and onRead() methods.
  public init()

  public required init(_ ptr: UnsafeMutableRawPointer)

  /// Sets the end handler for this custom target.
  /// 
  /// The end handler will be called when the target is being ended.
  /// Use this for cleanup operations like closing files or network connections.
  /// This replaces the deprecated finish handler.
  /// 
  /// - Parameter handler: A closure called when the target is ended
  ///   - Returns: 0 for success, non-zero for error
  public @discardableResult func onEnd(_ handler: @escaping () -> Int) -> Int

  /// Adds a read handler to this custom target.
  /// 
  /// The read handler enables reading back data that was previously written,
  /// which is required by some image formats (like TIFF). If your custom
  /// target doesn't support reading, don't set this handler.
  /// 
  /// - Parameter handler: A closure that handles read operations
  ///   - Parameter outputSpan: The destination span to read bytes into.
  public @discardableResult func onRead(_ handler: @escaping (inout OutputRawSpan) -> Void) -> Int

  /// Sets the seek handler for this custom target.
  /// 
  /// The seek handler enables random access within the target, which is
  /// required by some image formats (like TIFF). If your custom target
  /// doesn't support seeking, don't set this handler.
  /// 
  /// - Parameter handler: A closure that handles seek operations
  ///   - Parameter offset: Byte offset for the seek operation
  ///   - Parameter whence: How to interpret offset (SEEK_SET=0, SEEK_CUR=1, SEEK_END=2)
  ///   - Returns: New absolute position, or -1 for error
  public @discardableResult func onSeek(_ handler: @escaping (Int64, Whence) -> Int64) -> Int

  /// Adds a read handler to this custom target.
  /// 
  /// The read handler enables reading back data that was previously written,
  /// which is required by some image formats (like TIFF). If your custom
  /// target doesn't support reading, don't set this handler.
  /// 
  /// - Parameter handler: A closure that handles read operations
  ///   - Parameter buffer: The destination buffer to read bytes into.
  ///   - Returns: The actual number of bytes written to buffer.
  public @discardableResult func onUnsafeRead(_ handler: @escaping (UnsafeMutableRawBufferPointer) -> (Int)) -> Int

  /// Sets the write handler for this custom target.
  /// 
  /// The write handler will be called whenever data needs to be written
  /// to the target. It should consume as many bytes as possible and
  /// return the actual number of bytes written.
  /// 
  /// - Parameter handler: A closure that receives data and returns bytes written
  ///   - Parameter data: Buffer to write
  ///   - Returns: Number of bytes actually written (should be <= data.count)
  public @discardableResult func onUnsafeWrite(_ handler: @escaping (UnsafeRawBufferPointer) -> Int) -> Int

  public @discardableResult func onWrite(_ handler: @escaping (RawSpan) -> Int) -> Int
}
```

#### struct UnownedVIPSImageRef

```swift
public struct UnownedVIPSImageRef: PointerWrapper, VIPSImageProtocol, VIPSObjectProtocol {
  public var ptr: UnsafeMutableRawPointer!

  public init(_ ptr: UnsafeMutableRawPointer)
}
```

#### struct UnownedVIPSObjectRef

```swift
public struct UnownedVIPSObjectRef: PointerWrapper, VIPSObjectProtocol {
  public let ptr: UnsafeMutableRawPointer!

  public init(_ ptr: UnsafeMutableRawPointer)
}
```

#### struct VIPSError

```swift
public struct VIPSError: Error, Sendable, SendableMetatype {
  /// A textual representation of this instance.
  /// 
  /// Calling this property directly is discouraged. Instead, convert an
  /// instance of any type to a string by using the `String(describing:)`
  /// initializer. This initializer works with any type, and uses the custom
  /// `description` property for types that conform to
  /// `CustomStringConvertible`:
  /// 
  ///     struct Point: CustomStringConvertible {
  ///         let x: Int, y: Int
  /// 
  ///         var description: String {
  ///             return "(\(x), \(y))"
  ///         }
  ///     }
  /// 
  ///     let p = Point(x: 21, y: 30)
  ///     let s = String(describing: p)
  ///     print(s)
  ///     // Prints "(21, 30)"
  /// 
  /// The conversion of `p` to a string in the assignment to `s` uses the
  /// `Point` type's `description` property.
  public var description: String { get }

  public let message: String
}
```

#### struct VIPSObjectRef

```swift
public struct VIPSObjectRef: PointerWrapper, VIPSObjectProtocol {
  public let ptr: UnsafeMutableRawPointer!

  public init(_ ptr: UnsafeMutableRawPointer)

  public init(borrowing ref: UnownedVIPSObjectRef)
}
```

#### struct VIPSOption

```swift
public struct VIPSOption {
  public init()

  public mutating func set<V>(_ name: String, value: V) where V : RawRepresentable, V.RawValue : BinaryInteger

  public mutating func setAny(_ name: String, value: Any) throws
}
```

#### struct Whence

```swift
public struct Whence: RawRepresentable, Sendable, SendableMetatype {
  public static var current: Whence { get }

  public static var end: Whence { get }

  public static var set: Whence { get }

  /// The corresponding value of the raw type.
  /// 
  /// A new instance initialized with `rawValue` will be equivalent to this
  /// instance. For example:
  /// 
  ///     enum PaperSize: String {
  ///         case A4, A5, Letter, Legal
  ///     }
  /// 
  ///     let selectedSize = PaperSize.Letter
  ///     print(selectedSize.rawValue)
  ///     // Prints "Letter"
  /// 
  ///     print(selectedSize == PaperSize(rawValue: selectedSize.rawValue)!)
  ///     // Prints "true"
  public var rawValue: Int32

  /// Creates a new instance with the specified raw value.
  /// 
  /// If there is no value of the type that corresponds with the specified raw
  /// value, this initializer returns `nil`. For example:
  /// 
  ///     enum PaperSize: String {
  ///         case A4, A5, Letter, Legal
  ///     }
  /// 
  ///     print(PaperSize(rawValue: "Legal"))
  ///     // Prints "Optional(PaperSize.Legal)"
  /// 
  ///     print(PaperSize(rawValue: "Tabloid"))
  ///     // Prints "nil"
  /// 
  /// - Parameter rawValue: The raw value to use for the new instance.
  public init?(rawValue: Int32)
}
```

#### enum VIPS

```swift
public enum VIPS {
  public static func findLoader<Buffer>(buffer: Buffer) throws -> String where Buffer : Sequence, Buffer.Element == UInt8

  public static func findLoader(filename: String) -> String?

  public static func shutdown()

  public static func start(concurrency: Int = 0, logger: Logger = Logger(label: "VIPS"), loggingDelegate: VIPSLoggingDelegate? = nil) throws
}
```

#### protocol PointerWrapper

```swift
public protocol PointerWrapper : ~Copyable, ~Escapable {
  public var ptr: UnsafeMutableRawPointer! { get }

  public init(_ ptr: UnsafeMutableRawPointer)
}
```

#### protocol VIPSImageProtocol

```swift
public protocol VIPSImageProtocol : VIPSObjectProtocol, ~Copyable, ~Escapable {
  /// The number of bands (channels) in the image.
  public var bands: Int { get }

  /// The number of pixels down the image.
  public var height: Int { get }

  /// The kill flag for this image.
  /// 
  /// When getting: If the image has been killed, returns `true`. Otherwise returns `false`.
  /// 
  /// When setting: Set the kill flag on an image. Setting this to `true` will block eval
  /// and is handy for stopping sets of threads.
  /// 
  /// - SeeAlso: `setProgressReportingEnabled(_:)`
  public var kill: Bool { get nonmutating set }

  /// The number of pixels across the image.
  public var width: Int { get }

  /// Bandwise join a set of images
  /// 
  public static func bandjoin(_ in: [VIPSImage]) throws -> Self

  /// Band-wise rank of a set of images
  /// 
  public static func bandrank(_ in: [VIPSImage], index: Int? = nil) throws -> Self

  /// Make a black image
  /// 
  public static func black(width: Int, height: Int, bands: Int? = nil) throws -> Self

  /// Make an image showing the eye's spatial response
  /// 
  public static func eye(width: Int, height: Int, uchar: Bool? = nil, factor: Double? = nil) throws -> Self

  /// Make a fractal surface
  /// 
  public static func fractsurf(width: Int, height: Int, fractalDimension: Double) throws -> Self

  /// Make a gaussnoise image
  /// 
  public static func gaussnoise(width: Int, height: Int, sigma: Double? = nil, mean: Double? = nil, seed: Int? = nil) throws -> Self

  /// Make a grey ramp image
  /// 
  public static func grey(width: Int, height: Int, uchar: Bool? = nil) throws -> Self

  /// Make a 1D image where pixel values are indexes
  /// 
  public static func identity(bands: Int? = nil, ushort: Bool? = nil, size: Int? = nil) throws -> Self

  /// Make a butterworth filter
  /// 
  public static func maskButterworth(width: Int, height: Int, order: Double, frequencyCutoff: Double, amplitudeCutoff: Double, uchar: Bool? = nil, nodc: Bool? = nil, reject: Bool? = nil, optical: Bool? = nil) throws -> Self

  /// Make a butterworth_band filter
  /// 
  public static func maskButterworthBand(width: Int, height: Int, order: Double, frequencyCutoffX: Double, frequencyCutoffY: Double, radius: Double, amplitudeCutoff: Double, uchar: Bool? = nil, nodc: Bool? = nil, reject: Bool? = nil, optical: Bool? = nil) throws -> Self

  /// Make a butterworth ring filter
  /// 
  public static func maskButterworthRing(width: Int, height: Int, order: Double, frequencyCutoff: Double, amplitudeCutoff: Double, ringwidth: Double, uchar: Bool? = nil, nodc: Bool? = nil, reject: Bool? = nil, optical: Bool? = nil) throws -> Self

  /// Make fractal filter
  /// 
  public static func maskFractal(width: Int, height: Int, fractalDimension: Double, uchar: Bool? = nil, nodc: Bool? = nil, reject: Bool? = nil, optical: Bool? = nil) throws -> Self

  /// Make a gaussian filter
  /// 
  public static func maskGaussian(width: Int, height: Int, frequencyCutoff: Double, amplitudeCutoff: Double, uchar: Bool? = nil, nodc: Bool? = nil, reject: Bool? = nil, optical: Bool? = nil) throws -> Self

  /// Make a gaussian filter
  /// 
  public static func maskGaussianBand(width: Int, height: Int, frequencyCutoffX: Double, frequencyCutoffY: Double, radius: Double, amplitudeCutoff: Double, uchar: Bool? = nil, nodc: Bool? = nil, reject: Bool? = nil, optical: Bool? = nil) throws -> Self

  /// Make a gaussian ring filter
  /// 
  public static func maskGaussianRing(width: Int, height: Int, frequencyCutoff: Double, amplitudeCutoff: Double, ringwidth: Double, uchar: Bool? = nil, nodc: Bool? = nil, reject: Bool? = nil, optical: Bool? = nil) throws -> Self

  /// Make an ideal filter
  /// 
  public static func maskIdeal(width: Int, height: Int, frequencyCutoff: Double, uchar: Bool? = nil, nodc: Bool? = nil, reject: Bool? = nil, optical: Bool? = nil) throws -> Self

  /// Make an ideal band filter
  /// 
  public static func maskIdealBand(width: Int, height: Int, frequencyCutoffX: Double, frequencyCutoffY: Double, radius: Double, uchar: Bool? = nil, nodc: Bool? = nil, reject: Bool? = nil, optical: Bool? = nil) throws -> Self

  /// Make an ideal ring filter
  /// 
  public static func maskIdealRing(width: Int, height: Int, frequencyCutoff: Double, ringwidth: Double, uchar: Bool? = nil, nodc: Bool? = nil, reject: Bool? = nil, optical: Bool? = nil) throws -> Self

  /// Create an empty matrix image
  public static func matrix(width: Int, height: Int) throws -> Self

  /// Create a matrix image from a double array
  public static func matrix(width: Int, height: Int, data: [Double]) throws -> Self

  /// Make a perlin noise image
  /// 
  public static func perlin(width: Int, height: Int, cellSize: Int? = nil, uchar: Bool? = nil, seed: Int? = nil) throws -> Self

  /// Load named ICC profile
  /// 
  public static func profileLoad(name: String) throws -> VIPSBlob

  /// Make a 2D sine wave
  /// 
  public static func sines(width: Int, height: Int, uchar: Bool? = nil, hfreq: Double? = nil, vfreq: Double? = nil) throws -> Self

  /// Sum an array of images
  /// 
  public static func sum(_ in: [VIPSImage]) throws -> Self

  /// Find the index of the first non-zero pixel in tests
  /// 
  public static func `switch`(tests: [VIPSImage]) throws -> Self

  /// Build a look-up table
  /// 
  public static func tonelut(inMax: Int? = nil, outMax: Int? = nil, Lb: Double? = nil, Lw: Double? = nil, Ps: Double? = nil, Pm: Double? = nil, Ph: Double? = nil, S: Double? = nil, M: Double? = nil, H: Double? = nil) throws -> Self

  /// Make a worley noise image
  /// 
  public static func worley(width: Int, height: Int, cellSize: Int? = nil, seed: Int? = nil) throws -> Self

  /// Make an image where pixel values are coordinates
  /// 
  public static func xyz(width: Int, height: Int, csize: Int? = nil, dsize: Int? = nil, esize: Int? = nil) throws -> Self

  /// Make a zone plate
  /// 
  public static func zone(width: Int, height: Int, uchar: Bool? = nil) throws -> Self

  /// Transform LCh to CMC
  public func CMC2LCh() throws -> Self

  /// Transform CMYK to XYZ
  public func CMYK2XYZ() throws -> Self

  /// Transform HSV to sRGB
  public func HSV2sRGB() throws -> Self

  /// Transform LCh to CMC
  public func LCh2CMC() throws -> Self

  /// Transform LCh to Lab
  public func LCh2Lab() throws -> Self

  /// Transform Lab to LCh
  public func Lab2LCh() throws -> Self

  /// Transform float Lab to LabQ coding
  public func Lab2LabQ() throws -> Self

  /// Transform float Lab to signed short
  public func Lab2LabS() throws -> Self

  /// Transform CIELAB to XYZ
  /// 
  public func Lab2XYZ(temp: [Double]? = nil) throws -> Self

  /// Unpack a LabQ image to float Lab
  public func LabQ2Lab() throws -> Self

  /// Unpack a LabQ image to short Lab
  public func LabQ2LabS() throws -> Self

  /// Convert a LabQ image to sRGB
  public func LabQ2sRGB() throws -> Self

  /// Transform signed short Lab to float
  public func LabS2Lab() throws -> Self

  /// Transform short Lab to LabQ coding
  public func LabS2LabQ() throws -> Self

  /// Transform XYZ to CMYK
  public func XYZ2CMYK() throws -> Self

  /// Transform XYZ to Lab
  /// 
  public func XYZ2Lab(temp: [Double]? = nil) throws -> Self

  /// Transform XYZ to Yxy
  public func XYZ2Yxy() throws -> Self

  /// Transform XYZ to scRGB
  public func XYZ2scRGB() throws -> Self

  /// Transform Yxy to XYZ
  public func Yxy2XYZ() throws -> Self

  /// Absolute value of an image
  public func abs() throws -> Self

  /// Add two images
  /// 
  public func add(_ rhs: some VIPSImageProtocol) throws -> Self

  /// Bitwise AND of two images
  /// 
  public func andimage(_ rhs: some VIPSImageProtocol) throws -> Self

  /// Autorotate image by exif tag
  public func autorot() throws -> Self

  /// Find image average
  public func avg() throws -> Double

  /// Fold up x axis into bands
  /// 
  public func bandfold(factor: Int? = nil) throws -> Self

  /// Append a constant band to an image
  /// 
  public func bandjoinConst(c: [Double]) throws -> Self

  /// Band-wise average
  public func bandmean() throws -> Self

  /// Unfold image bands into x axis
  /// 
  public func bandunfold(factor: Int? = nil) throws -> Self

  /// Build a look-up table
  public func buildlut() throws -> Self

  /// Byteswap an image
  public func byteswap() throws -> Self

  /// Use pixel values to pick cases from an array of images
  /// 
  public func `case`(cases: [VIPSImage]) throws -> Self

  /// Clamp values of an image
  /// 
  public func clamp(min: Double? = nil, max: Double? = nil) throws -> Self

  /// Form a complex image from two real images
  /// 
  public func complexform(_ rhs: some VIPSImageProtocol) throws -> Self

  /// Approximate integer convolution
  /// 
  public func conva(mask: some VIPSImageProtocol, layers: Int? = nil, cluster: Int? = nil) throws -> Self

  /// Approximate separable integer convolution
  /// 
  public func convasep(mask: some VIPSImageProtocol, layers: Int? = nil) throws -> Self

  /// Float convolution operation
  /// 
  public func convf(mask: some VIPSImageProtocol) throws -> Self

  /// Int convolution operation
  /// 
  public func convi(mask: some VIPSImageProtocol) throws -> Self

  /// This function allocates memory, renders image into it, builds a new image
  /// around the memory area, and returns that.
  /// 
  /// If the image is already a simple area of memory, it just refs image and
  /// returns it.
  public func copyMemory() throws -> Self

  /// Calculate dE00
  /// 
  public func dE00(_ rhs: some VIPSImageProtocol) throws -> Self

  /// Calculate dE76
  /// 
  public func dE76(_ rhs: some VIPSImageProtocol) throws -> Self

  /// Calculate dECMC
  /// 
  public func dECMC(_ rhs: some VIPSImageProtocol) throws -> Self

  /// Find image standard deviation
  public func deviate() throws -> Double

  /// Divide two images
  /// 
  public func divide(_ rhs: some VIPSImageProtocol) throws -> Self

  /// Bitwise XOR of two images
  /// 
  public func eorimage(_ rhs: some VIPSImageProtocol) throws -> Self

  /// Test for equality
  /// 
  public func equal(_ value: Double) throws -> Self

  /// Extract an area from an image
  /// 
  public func extractArea(left: Int, top: Int, width: Int, height: Int) throws -> Self

  /// Extract band from an image
  /// 
  public func extractBand(_ band: Int, n: Int? = nil) throws -> Self

  /// False-color an image
  public func falsecolour() throws -> Self

  /// Fast correlation
  /// 
  public func fastcor(ref: some VIPSImageProtocol) throws -> Self

  /// Fill image zeros with nearest non-zero pixel
  public func fillNearest() throws -> Self

  /// Search an image for non-edge areas
  /// 
  public func findTrim(threshold: Double? = nil, background: [Double]? = nil, lineArt: Bool? = nil) throws -> Int

  /// Flatten alpha out of an image
  /// 
  public func flatten(background: [Double]? = nil, maxAlpha: Double? = nil) throws -> Self

  /// Transform float RGB to Radiance coding
  public func float2rad() throws -> Self

  /// Frequency-domain filtering
  /// 
  public func freqmult(mask: some VIPSImageProtocol) throws -> Self

  /// Forward FFT
  public func fwfft() throws -> Self

  /// Gamma an image
  /// 
  public func gamma(exponent: Double? = nil) throws -> Self

  /// Read a point from an image
  /// 
  public func getpoint(x: Int, y: Int, unpackComplex: Bool? = nil) throws -> [Double]

  /// Global balance an image mosaic
  /// 
  public func globalbalance(gamma: Double? = nil, intOutput: Bool? = nil) throws -> Self

  /// Grid an image
  /// 
  public func grid(tileHeight: Int, across: Int, down: Int) throws -> Self

  /// Form cumulative histogram
  public func histCum() throws -> Self

  /// Estimate image entropy
  public func histEntropy() throws -> Double

  /// Histogram equalisation
  /// 
  public func histEqual(band: Int? = nil) throws -> Self

  /// Find image histogram
  /// 
  public func histFind(band: Int? = nil) throws -> Self

  /// Find n-dimensional image histogram
  /// 
  public func histFindNdim(bins: Int? = nil) throws -> Self

  /// Test for monotonicity
  public func histIsmonotonic() throws -> Bool

  /// Local histogram equalisation
  /// 
  public func histLocal(width: Int, height: Int, maxSlope: Int? = nil) throws -> Self

  /// Match two histograms
  /// 
  public func histMatch(ref: some VIPSImageProtocol) throws -> Self

  /// Normalise histogram
  public func histNorm() throws -> Self

  /// Plot histogram
  public func histPlot() throws -> Self

  /// Find hough circle transform
  /// 
  public func houghCircle(scale: Int? = nil, minRadius: Int? = nil, maxRadius: Int? = nil) throws -> Self

  /// Find hough line transform
  /// 
  public func houghLine(width: Int? = nil, height: Int? = nil) throws -> Self

  /// Ifthenelse an image
  /// 
  public func ifthenelse(in1: some VIPSImageProtocol, in2: some VIPSImageProtocol, blend: Bool? = nil) throws -> Self

  /// Insert image @sub into @main at @x, @y
  /// 
  public func insert(sub: some VIPSImageProtocol, x: Int, y: Int, expand: Bool? = nil, background: [Double]? = nil) throws -> Self

  /// Invert an image
  public func invert() throws -> Self

  /// Build an inverted look-up table
  /// 
  public func invertlut(size: Int? = nil) throws -> Self

  /// Inverse FFT
  /// 
  public func invfft(real: Bool? = nil) throws -> Self

  /// Label regions in an image
  public func labelregions() throws -> Self

  /// Test for less than
  /// 
  public func less(_ value: Double) throws -> Self

  /// Test for less than or equal
  /// 
  public func lesseq(_ value: Double) throws -> Self

  /// Left shift
  /// 
  public func lshift(_ amount: Int) throws -> Self

  /// Map an image though a lut
  /// 
  public func maplut(lut: some VIPSImageProtocol, band: Int? = nil) throws -> Self

  /// First-order match of two images
  /// 
  public func match(sec: some VIPSImageProtocol, xr1: Int, yr1: Int, xs1: Int, ys1: Int, xr2: Int, yr2: Int, xs2: Int, ys2: Int, hwindow: Int? = nil, harea: Int? = nil, search: Bool? = nil, interpolate: VIPSInterpolate? = nil) throws -> Self

  /// Invert a matrix
  public func matrixinvert() throws -> Self

  /// Multiply two matrices
  /// 
  public func matrixmultiply(_ rhs: some VIPSImageProtocol) throws -> Self

  /// Find image maximum
  /// 
  public func max(size: Int? = nil) throws -> Double

  /// Maximum of a pair of images
  /// 
  public func maxpair(_ rhs: some VIPSImageProtocol) throws -> Self

  /// Measure a set of patches on a color chart
  /// 
  public func measure(h: Int, v: Int, left: Int? = nil, top: Int? = nil, width: Int? = nil, height: Int? = nil) throws -> Self

  /// Find image minimum
  /// 
  public func min(size: Int? = nil) throws -> Double

  /// Minimum of a pair of images
  /// 
  public func minpair(_ rhs: some VIPSImageProtocol) throws -> Self

  /// Test for greater than
  /// 
  public func more(_ value: Double) throws -> Self

  /// Test for greater than or equal
  /// 
  public func moreeq(_ value: Double) throws -> Self

  /// Pick most-significant byte from an image
  /// 
  public func msb(band: Int? = nil) throws -> Self

  /// Multiply two images
  /// 
  public func multiply(_ rhs: some VIPSImageProtocol) throws -> Self

  public func new(_ colors: [Double]) throws -> Self

  /// Test for inequality
  /// 
  public func notequal(_ value: Double) throws -> Self

  /// Bitwise OR of two images
  /// 
  public func orimage(_ rhs: some VIPSImageProtocol) throws -> Self

  /// Find threshold for percent of pixels
  /// 
  public func percent(_ percent: Double) throws -> Int

  /// Calculate phase correlation
  /// 
  public func phasecor(in2: some VIPSImageProtocol) throws -> Self

  /// Prewitt edge detector
  public func prewitt() throws -> Self

  /// Resample an image with a quadratic transform
  /// 
  public func quadratic(coeff: some VIPSImageProtocol, interpolate: VIPSInterpolate? = nil) throws -> Self

  /// Unpack Radiance coding to float RGB
  public func rad2float() throws -> Self

  /// Rank filter
  /// 
  public func rank(width: Int, height: Int, index: Int) throws -> Self

  /// Linear recombination with matrix
  /// 
  public func recomb(m: some VIPSImageProtocol) throws -> Self

  /// Remainder after integer division of an image and a constant
  /// 
  public func remainder(_ value: Int) throws -> Self

  /// Remainder after integer division of an image and a constant
  /// 
  public func remainderConst(c: [Double]) throws -> Self

  /// Rebuild an mosaiced image
  /// 
  public func remosaic(oldStr: String, newStr: String) throws -> Self

  /// Replicate an image
  /// 
  public func replicate(across: Int, down: Int) throws -> Self

  /// Rotate an image by a number of degrees
  /// 
  public func rotate(angle: Double, interpolate: VIPSInterpolate? = nil, background: [Double]? = nil, odx: Double? = nil, ody: Double? = nil, idx: Double? = nil, idy: Double? = nil) throws -> Self

  /// Right shift
  /// 
  public func rshift(_ amount: Int) throws -> Self

  /// Transform sRGB to HSV
  public func sRGB2HSV() throws -> Self

  /// Convert an sRGB image to scRGB
  public func sRGB2scRGB() throws -> Self

  /// Convert scRGB to BW
  /// 
  public func scRGB2BW(depth: Int? = nil) throws -> Self

  /// Transform scRGB to XYZ
  public func scRGB2XYZ() throws -> Self

  /// Convert scRGB to sRGB
  /// 
  public func scRGB2sRGB(depth: Int? = nil) throws -> Self

  /// Scale an image to uchar
  /// 
  public func scale(exp: Double? = nil, log: Bool? = nil) throws -> Self

  /// Scharr edge detector
  public func scharr() throws -> Self

  /// Check sequential access
  /// 
  public func sequential(tileHeight: Int? = nil) throws -> Self

  /// Enable or disable progress reporting for this image.
  /// 
  /// VIPS signals evaluation progress via the `preeval`, `eval` and `posteval` signals.
  /// Progress is signalled on the most-downstream image for which `setProgressReportingEnabled(_:)`
  /// was called with `true`.
  /// 
  /// - Parameter enabled: `true` to enable progress reporting, `false` to disable
  /// 
  /// - SeeAlso: `onPreeval(_:)`, `onEval(_:)`, `onPosteval(_:)`
  public func setProgressReportingEnabled(_ enabled: Bool)

  /// Unsharp masking for print
  /// 
  public func sharpen(sigma: Double? = nil, x1: Double? = nil, y2: Double? = nil, y3: Double? = nil, m1: Double? = nil, m2: Double? = nil) throws -> Self

  /// Shrink an image
  /// 
  public func shrink(hshrink: Double, vshrink: Double, ceil: Bool? = nil) throws -> Self

  /// Shrink an image horizontally
  /// 
  public func shrinkh(hshrink: Int, ceil: Bool? = nil) throws -> Self

  /// Shrink an image vertically
  /// 
  public func shrinkv(vshrink: Int, ceil: Bool? = nil) throws -> Self

  /// Unit vector of pixel
  public func sign() throws -> Self

  /// Similarity transform of an image
  /// 
  public func similarity(scale: Double? = nil, angle: Double? = nil, interpolate: VIPSInterpolate? = nil, background: [Double]? = nil, odx: Double? = nil, ody: Double? = nil, idx: Double? = nil, idy: Double? = nil) throws -> Self

  /// Sobel edge detector
  public func sobel() throws -> Self

  /// Spatial correlation
  /// 
  public func spcor(ref: some VIPSImageProtocol) throws -> Self

  /// Make displayable power spectrum
  public func spectrum() throws -> Self

  /// Find many image stats
  public func stats() throws -> Self

  /// Statistical difference
  /// 
  public func stdif(width: Int, height: Int, s0: Double? = nil, b: Double? = nil, m0: Double? = nil, a: Double? = nil) throws -> Self

  /// Subsample an image
  /// 
  public func subsample(xfac: Int, yfac: Int, point: Bool? = nil) throws -> Self

  /// Subtract two images
  /// 
  public func subtract(_ rhs: some VIPSImageProtocol) throws -> Self

  /// Transpose3d an image
  /// 
  public func transpose3d(pageHeight: Int? = nil) throws -> Self

  /// Wrap image origin
  /// 
  public func wrap(x: Int? = nil, y: Int? = nil) throws -> Self

  /// Zoom an image
  /// 
  public func zoom(xfac: Int, yfac: Int) throws -> Self
}
```

#### protocol VIPSLoggingDelegate

```swift
public protocol VIPSLoggingDelegate : AnyObject {
  public func debug(_ message: String)

  public func error(_ message: String)

  public func info(_ message: String)

  public func warning(_ message: String)
}
```

#### protocol VIPSObjectProtocol

```swift
public protocol VIPSObjectProtocol : PointerWrapper, ~Copyable, ~Escapable {
  public var type: GType { get }

  public func disconnect(signalHandler: Int)

  public @discardableResult func onPreClose(_ handler: @escaping (UnownedVIPSObjectRef) -> Void) -> Int
}
```

#### Array extension

```swift
extension Array {
}
```

#### Collection extension

```swift
extension Collection {
  public func vips_findLoader() throws -> String
}
```

#### Globals

```swift
public func vipsFindLoader(path: String) -> String?

public typealias VIPSProgress = Cvips.VipsProgress

public typealias VipsAccess = Cvips.VipsAccess

public typealias VipsAlign = Cvips.VipsAlign

public typealias VipsAngle = Cvips.VipsAngle

public typealias VipsAngle45 = Cvips.VipsAngle45

public typealias VipsArgumentFlags = Cvips.VipsArgumentFlags

public typealias VipsBandFormat = Cvips.VipsBandFormat

public typealias VipsBlendMode = Cvips.VipsBlendMode

public typealias VipsCoding = Cvips.VipsCoding

public typealias VipsCombine = Cvips.VipsCombine

public typealias VipsCombineMode = Cvips.VipsCombineMode

public typealias VipsCompassDirection = Cvips.VipsCompassDirection

public typealias VipsDemandStyle = Cvips.VipsDemandStyle

public typealias VipsDirection = Cvips.VipsDirection

public typealias VipsExtend = Cvips.VipsExtend

public typealias VipsFailOn = Cvips.VipsFailOn

public typealias VipsForeignFlags = Cvips.VipsForeignFlags

public typealias VipsForeignKeep = Cvips.VipsForeignKeep

public typealias VipsForeignSubsample = Cvips.VipsForeignSubsample

public typealias VipsImageType = Cvips.VipsImageType

public typealias VipsIntent = Cvips.VipsIntent

public typealias VipsInteresting = Cvips.VipsInteresting

public typealias VipsInterpretation = Cvips.VipsInterpretation

public typealias VipsKernel = Cvips.VipsKernel

public typealias VipsOperationBoolean = Cvips.VipsOperationBoolean

public typealias VipsOperationComplex = Cvips.VipsOperationComplex

public typealias VipsOperationComplex2 = Cvips.VipsOperationComplex2

public typealias VipsOperationComplexget = Cvips.VipsOperationComplexget

public typealias VipsOperationFlags = Cvips.VipsOperationFlags

public typealias VipsOperationMath = Cvips.VipsOperationMath

public typealias VipsOperationMath2 = Cvips.VipsOperationMath2

public typealias VipsOperationMorphology = Cvips.VipsOperationMorphology

public typealias VipsOperationRelational = Cvips.VipsOperationRelational

public typealias VipsOperationRound = Cvips.VipsOperationRound

public typealias VipsPCS = Cvips.VipsPCS

public typealias VipsPrecision = Cvips.VipsPrecision

public typealias VipsRegionShrink = Cvips.VipsRegionShrink

public typealias VipsSize = Cvips.VipsSize

public typealias VipsTextWrap = Cvips.VipsTextWrap
```

<!-- Generated by interfazzle.swift on 2025-12-15 22:40:04 +0100 -->
