import Foundation

/// Errors raised while producing the scanner output files.
enum CunningScannerError: LocalizedError {
    /// The page at the given index could not be encoded to the requested image format.
    case encodingFailed(page: Int)

    var errorDescription: String? {
        switch self {
        case .encodingFailed(let page):
            return "Failed to encode scanned page \(page) to the requested image format"
        }
    }
}

/// Defines the output image format configurations.
enum CunningScannerImageFormat: String {
    case jpg
    case png
}

/// Defines the source to scan documents from.
enum CunningScannerSource: String {
    case camera
    case gallery
    case cameraAndGallery = "camera_and_gallery"
}

/// The files a scan must produce, mirroring the Dart `ScanOutput` enum.
enum CunningScanOutput: String {
    case images
    case pdf
    case imagesAndPdf = "images_and_pdf"

    /// Whether one image file per page is returned.
    var wantsImages: Bool { self != .pdf }

    /// Whether a PDF document holding every page is returned.
    var wantsPdf: Bool { self != .images }
}

/// A structure to hold document scanner configuration parameters.
struct CunningScannerOptions {
    /// Target image format (PNG or JPG).
    let imageFormat: CunningScannerImageFormat
    
    /// The compression quality from 0.0 to 1.0 (only applicable for JPG output).
    let jpgCompressionQuality: Double
    
    /// The files the scan returns: page images, a PDF, or both.
    let output: CunningScanOutput

    /// The target source for scanning (camera, gallery, or both).
    let scannerSource: CunningScannerSource

    /// Maximum number of pages allowed for scanning.
    let noOfPages: Int

    /// The filter preselected when the custom cropper opens a page.
    let defaultFilter: DocumentFilter

    /// Whether the filter selector is shown in the custom cropper.
    let showFilterBar: Bool

    /// Creates scanner options with default settings.
    init() {
        self.imageFormat = .png
        self.jpgCompressionQuality = 1.0
        self.output = .images
        self.scannerSource = .camera
        self.noOfPages = 100
        self.defaultFilter = .original
        self.showFilterBar = true
    }

    /// Creates scanner options with specified settings.
    init(
        imageFormat: CunningScannerImageFormat,
        jpgCompressionQuality: Double,
        output: CunningScanOutput,
        scannerSource: CunningScannerSource,
        noOfPages: Int = 100,
        defaultFilter: DocumentFilter = .original,
        showFilterBar: Bool = true
    ) {
        self.imageFormat = imageFormat
        self.jpgCompressionQuality = jpgCompressionQuality
        self.output = output
        self.scannerSource = scannerSource
        self.noOfPages = noOfPages
        self.defaultFilter = defaultFilter
        self.showFilterBar = showFilterBar
    }

    /// Splits `pageCount` scanned pages into those returned under `noOfPages` and those dropped.
    ///
    /// The document camera has no page limit of its own, so the excess is cut afterwards and
    /// its size reported to Dart as `discardedPages`. Negative inputs count as zero, so the
    /// result is always safe to use as a range bound.
    func pageSplit(forScanned pageCount: Int) -> (kept: Int, discarded: Int) {
        let scanned = max(pageCount, 0)
        let kept = min(scanned, max(noOfPages, 0))
        return (kept, scanned - kept)
    }

    /// Factory method to build a CunningScannerOptions object from incoming Flutter MethodChannel arguments.
    static func fromArguments(args: Any?) -> CunningScannerOptions {
        guard let arguments = args as? [String: Any] else {
            return CunningScannerOptions()
        }

        let output = CunningScanOutput(rawValue: (arguments["output"] as? String) ?? "") ?? .images
        let noOfPages = (arguments["noOfPages"] as? Int) ?? 100
        let sourceString = arguments["scannerSource"] as? String
        let scannerSource = CunningScannerSource(rawValue: sourceString ?? "") ?? .camera
        
        let scannerOptionsDict = arguments["iosScannerOptions"] as? [String: Any]
        let imageFormat = (scannerOptionsDict?["imageFormat"] as? String) ?? "png"
        let jpgCompressionQuality = (scannerOptionsDict?["jpgCompressionQuality"] as? Double) ?? 1.0
        let defaultFilterName = (scannerOptionsDict?["defaultFilter"] as? String) ?? "original"
        let showFilterBar = (scannerOptionsDict?["showFilterBar"] as? Bool) ?? true

        return CunningScannerOptions(
            imageFormat: CunningScannerImageFormat(rawValue: imageFormat) ?? .png,
            jpgCompressionQuality: jpgCompressionQuality,
            output: output,
            scannerSource: scannerSource,
            noOfPages: noOfPages,
            defaultFilter: DocumentFilter(methodChannelValue: defaultFilterName),
            showFilterBar: showFilterBar
        )
    }
}
