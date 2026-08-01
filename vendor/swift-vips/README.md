# SwiftVIPS

A modern Swift wrapper around [libvips](https://github.com/libvips/libvips), the fast image processing library. SwiftVIPS provides a Swift-native API for libvips' [300+ image processing operations](https://www.libvips.org/API/current/function-list.html) with full Linux compatibility.

## Features

- 🚀 **Fast & Memory Efficient**: Built on libvips' demand-driven, horizontally threaded architecture
- 🔢 **Operator Overloading**: Intuitive arithmetic operations (`+`, `-`, `*`, `/`)
- 📁 **Format Support**: JPEG, PNG, TIFF, WebP, HEIF, GIF, PDF, SVG and more
- 🐧 **Linux Compatible**: Cross-platform support
- 🧠 **Memory Safe**: Automatic memory management with proper reference counting

## Installation

Add SwiftVIPS to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/t089/swift-vips.git", branch: "main")
]
```

### System Requirements

Install libvips on your system:

**macOS:**
```bash
brew install vips
```

**Ubuntu/Debian:**
```bash
apt-get update && apt-get install -y libvips-dev
```

**Other systems:** See [libvips installation guide](https://www.libvips.org/install.html)

**Container:**

You can use the containers provided at `ghcr.io/t089/swift-vips-builder` to get a ready-to-use development environment with both Swift and libvips installed.

## Quick Start

```swift
import VIPS

// Initialize VIPS once per application
try VIPS.start()

// Load, resize, and save an image
try VIPSImage(fromFilePath: "input.jpg")
    .thumbnailImage(width: 800, height: 600, crop: .attention)
    .writeToFile("output.jpg", quality: 85)
```

## Examples

### Image Loading

```swift
// Load from file
let image = try VIPSImage(fromFilePath: "photo.jpg")
print("Size: \(image.size.width)×\(image.size.height)")

// Load from memory buffer
let data = try Data(contentsOf: URL(fileURLWithPath: "photo.jpg"))
let imageFromBuffer = try VIPSImage(data: data)

// Create from raw pixel data
let pixels = Array(repeating: UInt8(255), count: 100 * 100 * 3) // White 100×100 RGB
let rawImage = try VIPSImage(
    data: pixels,
    width: 100, 
    height: 100,
    bands: 3,
    format: .uchar
)
```

### Image Transformations

```swift
let image = try VIPSImage(fromFilePath: "input.jpg")

// Resize with scale factor
let resized = try image.resize(scale: 0.5)

// Create thumbnail with smart cropping
let thumbnail = try image.thumbnailImage(width: 200, height: 200, crop: .attention)
```

### Arithmetic Operations with Operator Overloading

```swift
let image1 = try VIPSImage(fromFilePath: "photo1.jpg")
let image2 = try VIPSImage(fromFilePath: "photo2.jpg")

// Image arithmetic
let sum = try image1 + image2
let difference = try image1 - image2
let product = try image1 * image2
let quotient = try image1 / image2

// Scalar operations
let brightened = try image1 + 50          // Add 50 to all pixels
let dimmed = try image1 * 0.8             // Scale all pixels by 0.8
let enhanced = try image1 * [1.2, 1.0, 0.9] // Per-channel scaling

// Linear transformation: a * image + b
let linearized = try image1.linear([1.1, 1.0, 0.9], [10, 0, -5])
```

### Format-Specific Saving

```swift
let image = try VIPSImage(fromFilePath: "input.tiff")

// Save to file with quality control
try image.writeToFile("output.jpg", quality: 85)

// Export to memory buffer
let jpegBuffer = try image.jpegsave(quality: 90)
let pngBuffer = try image.pngsave(compression: 6) 
let webpBuffer = try image.webpsave(quality: 80, lossless: false)

// Generic format export based on file extension
let buffer = try image.writeToBuffer(suffix: ".png", quality: 95)
```

### Advanced Processing Pipeline

```swift
// Complex image processing chain
let processed = try VIPSImage(fromFilePath: "raw-photo.jpg")
    .autorot()                    // Auto-rotate based on EXIF
    .thumbnailImage(width: 1200, height: 800, crop: .smart)
    .linear([1.1, 1.0, 0.9], [0, 0, 0])  // Color correction
    .gamma(exponent: 1.2)         // Gamma adjustment
    
try processed.writeToFile("processed.jpg", quality: 92)
```

### Mathematical and Statistical Operations

```swift
let image = try VIPSImage(fromFilePath: "photo.jpg")

// Statistical operations
let avgValue = try image.avg()            // Average pixel value
let deviation = try image.deviate()       // Standard deviation

// Mathematical functions
let absolute = try image.abs()            // Absolute values
let inverted = try image.invert()         // Invert image
let squared = try image.square()          // Square pixel values

// Get pixel value at specific coordinates
let pixelValue = try image.getpoint(x: 100, y: 50) // Returns [Double] for all bands
```

### Working with Image Bands

```swift
let rgbImage = try VIPSImage(fromFilePath: "photo.jpg")

// Extract a single band (channel)
let redChannel = try rgbImage.extractBand(0)        // Extract red channel
let greenChannel = try rgbImage.extractBand(1)      // Extract green channel

// Add constant values as new bands (e.g., add alpha channel)
let withAlpha = try rgbImage.bandjoinConst(c: [255]) // Add opaque alpha
```

## API Overview

The Swift API follows largely the naming and conventions of the C library with minor adjustments to make it more idiomatic in Swift.

### Core Classes

- **`VIPS`**: Library initialization and shutdown
- **`VIPSImage`**: Main image class with processing operations
- **`VIPSBlob`**: Binary data container
- **`VIPSError`**: The error thrown by all libvips operations
- **`VIPSSource`/`VIPSTarget`**: Advanced I/O operations

### Key Methods

**Loading:**
- `VIPSImage(fromFilePath:)` - Load from file
- `VIPSImage(data:)` - Load from memory buffer
- `VIPSImage(data:width:height:bands:format:)` - Create from raw pixels

**Transformations:**
- `resize(scale:)` - Resize by scale factor
- `thumbnailImage(width:height:crop:)` - Create thumbnail with cropping
- `extractArea(left:top:width:height:)` - Extract rectangular region
- `rotate(angle:)` - Rotate by degrees
- `flip(direction:)` - Flip horizontally or vertically
- `autorot()` - Auto-rotate based on EXIF

**Arithmetic:**
- `add()`, `subtract()`, `multiply()`, `divide()` - Basic math
- `linear()` - Linear transformation: `a * image + b`
- `gamma()` - Gamma correction
- `invert()` - Invert pixel values
- Operator overloading: `+`, `-`, `*`, `/`

**Statistics:**
- `avg()` - Average pixel value
- `deviate()` - Standard deviation
- `getpoint(x:y:)` - Get pixel value at coordinates

**Band Operations:**
- `extractBand(_:)` - Extract single band/channel
- `bandjoinConst(c:)` - Add constant values as new bands

**Export:**
- `writeToFile(_:quality:)` - Save to file
- `writeToBuffer(suffix:quality:)` - Export to memory
- `jpegsave()`, `pngsave()`, `webpsave()` - Format-specific export

### Properties

- `size` - Image dimensions as `Size` struct
- `width`, `height` - Image dimensions
- `bands` - Number of channels (e.g., 3 for RGB, 4 for RGBA)  
- `format` - Pixel format (`.uchar`, `.float`, etc.)
- `hasAlpha` - Whether image has transparency
- `orientation` - EXIF orientation value
- `space` - Color space interpretation as string

## Performance considerations

libvips tries to avoid copies of data as much as possible. When interfacing with Swift this can be challenging. For safety reasons, most APIs copy data into the VIPS classes. For maximum performance, you may want to avoid those copies and let libvips only "borrow" your memory.

Example:

```swift
let imageData: Data = // ... some data from somewhere
let image = VIPSImage(data: imageData) // the data is copied and "owned" by VIPSImage.
```

To avoid the copy, you need access to the raw storage of `imageData`:

```swift
let imageData: Data = // ... some data from somewhere
let jpeg: VIPSBlob = imageData.withUnsafeBytes { buffer in 
    let image = VIPSImage(unsafeData: buffer)
    // image or any image created from it MUST not escape the closure.
    return image.jpegsave() // returning data is safe
}
```

When SwiftVIPS returns data, it always returns an instance of `VIPSBlob`. SwiftVIPS can work with `VIPSBlob` directly without the need to copy data. `VIPSBlob` conforms to `Collection`, so you can easily convert it to other Swift types such as `Array<UInt8>` or `Data`:

```swift
let blob: VIPSBlob = ...
let array = Array(blob) // copies data
let data = Data(blob) // copies data

// with `Data` you can even avoid the copy:
let dataNoCopy = blob.withUnsafeBytesAndStorageManagement { buffer, storageManagement in
            _ = storageManagement.retain()
            return Data(
                bytesNoCopy: .init(mutating: buffer.baseAddress!),
                count: buffer.count,
                deallocator: .custom { ptr, _ in
                    storageManagement.release()
                }
            )
        }
```

## Development Commands

```bash
# Build the project
swift build

# Run tests (uses Swift Testing framework)
swift test

# Build and run example tool
swift run vips-tool

# Release build
swift build -c release
```

## Requirements

- Swift 6.2+
- libvips 8.12+ installed on system
- Linux or macOS

## Architecture

SwiftVIPS mirrors libvips' modular structure:

- **`Core/`**: Initialization, memory management, fundamental types
- **`Arithmetic/`**: Mathematical operations and operator overloading
- **`Conversion/`**: Image transformations and geometric operations
- **`Foreign/`**: File format support (organized by format)
- **`CvipsShim/`**: C interoperability layer

Code generation uses a SwiftPM build plugin that automatically generates Swift wrappers from libvips introspection at build time.

## Performance

SwiftVIPS inherits libvips' performance characteristics:

- **Demand-driven**: Only processes pixels when needed
- **Streaming**: Can handle images larger than available RAM
- **Multithreaded**: Automatic parallelization across CPU cores
- **Minimal copying**: Efficient memory usage

Copyright 2025 Tobias Haeberle
