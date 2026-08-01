import Cvips

extension VIPSImage {
    /// Project rows and columns to get sums.
    ///
    /// Returns two 1D images containing the sum of each row and column.
    /// Useful for creating projections and histograms.
    ///
    /// - Returns: A tuple containing (row sums, column sums)
    /// - Throws: `VIPSError` if the operation fails
    public func project() throws -> (rows: VIPSImage, columns: VIPSImage) {
        var rowsOut: UnsafeMutablePointer<VipsImage>?
        var columnsOut: UnsafeMutablePointer<VipsImage>?
        
        var opt = VIPSOption()
        
        opt.set("in", value: self.image)
        opt.set("rows", value: &rowsOut)
        opt.set("columns", value: &columnsOut)
        
        try VIPSImage.call("project", options: &opt)
        
        guard let rowsPtr = rowsOut, let colsPtr = columnsOut else {
            throw VIPSError("Failed to get projection outputs")
        }
        
        let rows = VIPSImage { ptr in
            ptr = rowsPtr
        }
        
        let columns = VIPSImage { ptr in
            ptr = colsPtr
        }
        
        return (rows, columns)
    }

    /// Extract profiles from an image.
    ///
    /// Creates 1D profiles by averaging across rows and columns.
    /// Returns two images: column profile (vertical average) and row profile (horizontal average).
    ///
    /// - Returns: A tuple containing (columns profile, rows profile)
    /// - Throws: `VIPSError` if the operation fails
    public func profile() throws -> (columns: VIPSImage, rows: VIPSImage) {
        var columnsOut: UnsafeMutablePointer<VipsImage>?
        var rowsOut: UnsafeMutablePointer<VipsImage>?
        
        var opt = VIPSOption()
        
        opt.set("in", value: self.image)
        opt.set("columns", value: &columnsOut)
        opt.set("rows", value: &rowsOut)
        
        try VIPSImage.call("profile", options: &opt)
        
        guard let colsPtr = columnsOut, let rowsPtr = rowsOut else {
            throw VIPSError("Failed to get profile outputs")
        }
        
        let columns = VIPSImage { ptr in
            ptr = colsPtr
        }
        
        let rows = VIPSImage { ptr in
            ptr = rowsPtr
        }
        
        return (columns, rows)
    }
 }