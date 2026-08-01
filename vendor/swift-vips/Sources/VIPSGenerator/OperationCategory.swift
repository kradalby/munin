/// Categorize operation based on its name
func getOperationCategory(_ nickname: String) -> String {
    let name = nickname.lowercased()

    // Foreign operations (file I/O)
    if name.contains("load") || name.contains("save") {
        if name.contains("jpeg") || name.contains("jpg") {
            return "Foreign/JPEG"
        } else if name.contains("png") {
            return "Foreign/PNG"
        } else if name.contains("webp") {
            return "Foreign/WebP"
        } else if name.contains("tiff") || name.contains("tif") {
            return "Foreign/TIFF"
        } else if name.contains("pdf") {
            return "Foreign/PDF"
        } else if name.contains("svg") {
            return "Foreign/SVG"
        } else if name.contains("heif") || name.contains("heic") {
            return "Foreign/HEIF"
        } else if name.contains("gif") {
            return "Foreign/GIF"
        } else {
            return "Foreign/Other"
        }
    }

    // Arithmetic operations
    let arithmeticOps = ["add", "subtract", "multiply", "divide", "abs", "linear",
                        "math", "complex", "remainder", "boolean", "relational",
                        "round", "sign", "avg", "min", "max", "deviate", "sum",
                        "invert", "stats"]
    if arithmeticOps.contains(where: { name.contains($0) }) {
        return "Arithmetic"
    }

    // Convolution operations
    let convOps = ["conv", "sharpen", "blur", "sobel", "canny", "gaussblur"]
    if convOps.contains(where: { name.contains($0) }) {
        return "Convolution"
    }

    // Colour operations
    let colourOps = ["colour", "color", "lab", "xyz", "srgb", "rgb", "cmyk",
                    "hsv", "lch", "yxy", "scrgb", "icc"]
    if colourOps.contains(where: { name.contains($0) }) {
        return "Colour"
    }

    // Conversion operations
    let conversionOps = ["resize", "rotate", "flip", "crop", "embed", "extract",
                        "shrink", "reduce", "zoom", "affine", "similarity", "scale",
                        "autorot", "rot", "recomb", "bandjoin", "bandrank",
                        "bandsplit", "cast", "copy", "tilecache", "arrayjoin",
                        "grid", "transpose", "wrap", "unpremultiply", "premultiply",
                        "composite", "join", "insert"]
    if conversionOps.contains(where: { name.contains($0) }) {
        return "Conversion"
    }

    // Create operations
    let createOps = ["black", "xyz", "grey", "mask", "gaussmat", "logmat", "text",
                    "gaussnoise", "eye", "zone", "sines", "buildlut", "identity",
                    "fractsurf", "radload", "tonelut", "worley", "perlin"]
    if createOps.contains(where: { name.contains($0) }) {
        return "Create"
    }

    // Draw operations
    if name.contains("draw") {
        return "Draw"
    }

    // Histogram operations
    let histOps = ["hist", "heq", "hough", "profile", "project", "spectrum", "phasecor"]
    if histOps.contains(where: { name.contains($0) }) {
        return "Histogram"
    }

    // Morphology operations
    let morphOps = ["morph", "erode", "dilate", "median", "rank", "countlines", "labelregions"]
    if morphOps.contains(where: { name.contains($0) }) {
        return "Morphology"
    }

    // Frequency domain operations
    let freqOps = ["fft", "invfft", "freqmult", "spectrum", "phasecor"]
    if freqOps.contains(where: { name.contains($0) }) {
        return "Freqfilt"
    }

    // Resample operations
    let resampleOps = ["shrink", "reduce", "resize", "thumbnail", "mapim", "quadratic"]
    if resampleOps.contains(where: { name.contains($0) }) {
        return "Resample"
    }

    return "Misc"
}
