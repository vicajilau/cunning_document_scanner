import Foundation

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

/// A structure to hold document scanner configuration parameters.
struct CunningScannerOptions {
    /// Target image format (PNG or JPG).
    let imageFormat: CunningScannerImageFormat
    
    /// The compression quality from 0.0 to 1.0 (only applicable for JPG output).
    let jpgCompressionQuality: Double
    
    /// If true, outputs scanned images combined into a single PDF document.
    let asPdf: Bool
    
    /// Deprecated property indicating whether gallery selection is permitted.
    let isGalleryImportAllowed: Bool
    
    /// The target source for scanning (camera, gallery, or both).
    let scannerSource: CunningScannerSource

    /// Maximum number of pages allowed for scanning.
    let noOfPages: Int

    /// Creates scanner options with default settings.
    init() {
        self.imageFormat = .png
        self.jpgCompressionQuality = 1.0
        self.asPdf = false
        self.isGalleryImportAllowed = false
        self.scannerSource = .camera
        self.noOfPages = 100
    }

    /// Creates scanner options with specified settings.
    init(imageFormat: CunningScannerImageFormat, jpgCompressionQuality: Double, asPdf: Bool, isGalleryImportAllowed: Bool, scannerSource: CunningScannerSource, noOfPages: Int = 100) {
        self.imageFormat = imageFormat
        self.jpgCompressionQuality = jpgCompressionQuality
        self.asPdf = asPdf
        self.isGalleryImportAllowed = isGalleryImportAllowed
        self.scannerSource = scannerSource
        self.noOfPages = noOfPages
    }

    /// Factory method to build a CunningScannerOptions object from incoming Flutter MethodChannel arguments.
    static func fromArguments(args: Any?) -> CunningScannerOptions {
        guard let arguments = args as? [String: Any] else {
            return CunningScannerOptions()
        }

        let asPdf = (arguments["asPdf"] as? Bool) ?? false
        let isGalleryImportAllowed = (arguments["isGalleryImportAllowed"] as? Bool) ?? false
        let noOfPages = (arguments["noOfPages"] as? Int) ?? 100
        let sourceString = arguments["scannerSource"] as? String
        let scannerSource = CunningScannerSource(rawValue: sourceString ?? "") ?? (isGalleryImportAllowed ? .cameraAndGallery : .camera)
        
        let scannerOptionsDict = arguments["iosScannerOptions"] as? [String: Any]
        let imageFormat = (scannerOptionsDict?["imageFormat"] as? String) ?? "png"
        let jpgCompressionQuality = (scannerOptionsDict?["jpgCompressionQuality"] as? Double) ?? 1.0

        return CunningScannerOptions(
            imageFormat: CunningScannerImageFormat(rawValue: imageFormat) ?? .png,
            jpgCompressionQuality: jpgCompressionQuality,
            asPdf: asPdf,
            isGalleryImportAllowed: isGalleryImportAllowed,
            scannerSource: scannerSource,
            noOfPages: noOfPages
        )
    }
}
