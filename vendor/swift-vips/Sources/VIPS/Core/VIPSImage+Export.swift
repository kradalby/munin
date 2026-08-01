import Cvips
import CvipsShim

extension VIPSImage {
    /// Writes the image to a memory buffer in the specified format.
    ///
    /// This method writes the image to a memory buffer using a format determined by the suffix.
    /// Save options may be appended to the suffix as `[name=value,...]` or given in the params
    /// dictionary. Options given in the function call override options given in the filename.
    ///
    /// Currently TIFF, JPEG, PNG and other formats are supported depending on your libvips build.
    /// You can call the various save operations directly if you wish, see `jpegsave(buffer:)` for example.
    ///
    /// - Parameters:
    ///   - suffix: Format to write (e.g., ".jpg", ".png", ".tiff")
    ///   - quality: Optional quality setting (format-dependent)
    ///   - params: Dictionary of additional save options
    ///   - additionalOptions: Optional string of additional options in libvips format
    /// - Returns: VIPSBlob containing the encoded image data
    /// - Throws: VIPSError if the write operation fails
    /// - SeeAlso: `VIPSImage.init(fromBuffer:)`
    public func writeToBuffer(
        suffix: String,
        quality: Int? = nil,
        options params: [String: Any] = [:],
        additionalOptions: String? = nil
    ) throws -> VIPSBlob {
        guard let name = vips_foreign_find_save_buffer(suffix) else {
            throw VIPSError()
        }

        let outBuf = UnsafeMutablePointer<UnsafeMutablePointer<VipsBlob>?>.allocate(capacity: 1)
        defer {
            outBuf.deallocate()
        }

        var options = VIPSOption()
        options.set("in", value: self.image)
        if let q = quality { options.set("Q", value: q) }
        options.set("buffer", value: outBuf)
        for (key, value) in params {
            try options.setAny(key, value: value)
        }

        try VIPSImage.call(name, optionsString: additionalOptions, options: &options)

        let blob = outBuf.pointee

        return VIPSBlob(blob)
    }

    /// Writes the image to a file.
    ///
    /// This method writes the image to a file using the saver recommended by the filename extension.
    /// Save options may be appended to the filename as `[name=value,...]` or given in the options
    /// dictionary. Options given in the function call override options given in the filename.
    ///
    /// - Parameters:
    ///   - path: File path to write to
    ///   - quality: Optional quality setting (format-dependent)
    ///   - options: Dictionary of additional save options
    ///   - additionalOptions: Optional string of additional options in libvips format
    /// - Throws: VIPSError if the write operation fails
    /// - SeeAlso: `VIPSImage.init(fromFile:)`
    public func writeToFile(
        _ path: String,
        quality: Int? = nil,
        options: [String: Any] = [:],
        additionalOptions: String? = nil
    ) throws {
        guard let opName = vips_foreign_find_save(path) else {
            throw VIPSError()
        }

        var option = VIPSOption()

        option.set("filename", value: path)
        if let q = quality {
            option.set("Q", value: q)
        }
        option.set("in", value: self.image)

        for (key, value) in options {
            try option.setAny(key, value: value)
        }

        try VIPSImage.call(opName, optionsString: additionalOptions, options: &option)
    }

    /// Writes the image to a target in the specified format.
    ///
    /// This method writes the image to a target using a format determined by the suffix.
    /// Save options may be appended to the suffix as `[name=value,...]` or given in the params
    /// dictionary. Options given in the function call override options given in the filename.
    ///
    /// You can call the various save operations directly if you wish, see `jpegsave(target:)` for example.
    ///
    /// - Parameters:
    ///   - suffix: Format to write (e.g., ".jpg", ".png", ".tiff")
    ///   - target: Target to write to
    ///   - quality: Optional quality setting (format-dependent)
    ///   - params: Dictionary of additional save options
    ///   - additionalOptions: Optional string of additional options in libvips format
    /// - Throws: VIPSError if the write operation fails
    /// - SeeAlso: `writeToFile(_:)`
    public func writeToTarget(
        suffix: String,
        target: VIPSTarget,
        quality: Int? = nil,
        options params: [String: Any] = [:],
        additionalOptions: String? = nil
    ) throws {
        guard let opName = vips_foreign_find_save_target(suffix) else {
            throw VIPSError()
        }

        var option = VIPSOption()

        option.set("in", value: self.image)
        option.set("target", value: target.target)
        if let q = quality {
            option.set("Q", value: q)
        }

        for (key, value) in params {
            try option.setAny(key, value: value)
        }

        try VIPSImage.call(opName, optionsString: additionalOptions, options: &option)
    }
}
