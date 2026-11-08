import AVFoundation
import Flutter
import UIKit
import Vision
import VisionKit
import PDFKit
import Photos
import PhotosUI

/// Main iOS plugin class for cunning_document_scanner.
/// Handles Flutter MethodChannel calls to launch camera or photo gallery scanning flows.
public class CunningDocumentScannerPlugin: NSObject,
    FlutterPlugin,
    VNDocumentCameraViewControllerDelegate,
    UIImagePickerControllerDelegate,
    UINavigationControllerDelegate {
    
    /// Name of the private subdirectory, inside the app caches directory, holding plugin output.
    static let storageDirectoryName = "cunning_document_scanner"

    /// Filename prefix applied to every file the plugin writes.
    static let scanFilePrefix = "DOCUMENT_SCAN_"

    /// The Flutter channel result callback pointer to return document paths to Dart/Flutter.
    ///
    /// Set for the duration of a single `scanDocuments` flow and cleared by `finish(_:)`.
    /// A `FlutterResult` must be invoked exactly once, so it is consumed rather than reused.
    var resultChannel: FlutterResult?

    /// The native VNDocumentCameraViewController presenting instance.
    var presentingController: VNDocumentCameraViewController?
    
    /// The options passed from the Dart/Flutter side.
    var scannerOptions = CunningScannerOptions()

    /// Pages the user scanned beyond `noOfPages` in the current flow, which were dropped.
    ///
    /// The document camera has no page limit of its own, so the excess can only be cut
    /// afterwards; it is reported to Dart instead of disappearing without a trace.
    var discardedPages = 0

    /// Set right before the Camera or Gallery action sheet entries open their own flow.
    ///
    /// UIKit calls `presentationControllerDidDismiss` for that dismissal too, not only for a
    /// user tapping outside/swiping the sheet away, so this distinguishes the two: the delegate
    /// clears it and ignores the callback when set, otherwise it treats the dismissal as a cancel.
    var isHandlingAlertAction = false

    /// Resolves the current visible or root UIViewController on the key window.
    var rootViewController: UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? (UIApplication.shared.delegate?.window ?? nil)
        return keyWindow?.rootViewController
    }

    /// Registers the plugin instance with the Flutter registrar.
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "cunning_document_scanner", binaryMessenger: registrar.messenger())
        let instance = CunningDocumentScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    /// Handles incoming FlutterMethodCalls. Specifically listens to "scanDocuments" and "cleanCache" methods.
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "cleanCache" {
            self.cleanCache(result: result)
            return
        }

        guard call.method == "scanDocuments" else {
            result(FlutterMethodNotImplemented)
            return
        }

        // A single result callback is held at a time. Starting a second scan would orphan
        // the first one (its Dart Future would never complete) and invoking a FlutterResult
        // twice traps, so the concurrent call is rejected instead.
        guard resultChannel == nil else {
            result(FlutterError(
                code: "ALREADY_ACTIVE",
                message: "A document scan is already in progress",
                details: nil
            ))
            return
        }

        // Without a presenter nothing can be shown, and the result callback would be
        // stored with no flow left to release it, locking out every later call.
        guard let presentedVC = rootViewController else {
            result(FlutterError(
                code: "NO_VIEW_CONTROLLER",
                message: "No view controller available to present the scanner",
                details: nil
            ))
            return
        }

        scannerOptions = CunningScannerOptions.fromArguments(args: call.arguments)
        discardedPages = 0
        resultChannel = result

        switch scannerOptions.scannerSource {
        case .camera:
            self.openCamera(from: presentedVC)
        case .gallery:
            self.openGallery(from: presentedVC)
        case .cameraAndGallery:
            let labelCamera = getLocalizedOption("cunning_document_scanner_camera", defaultValue: "Camera")
            let labelGallery = getLocalizedOption("cunning_document_scanner_gallery", defaultValue: "Gallery")
            let labelCancel = getLocalizedOption("cunning_document_scanner_cancel", defaultValue: "Cancel")
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            alertController.view.tintColor = .systemBlue
            
            let cameraAction = UIAlertAction(title: labelCamera, style: .default) { _ in
                self.isHandlingAlertAction = true
                self.openCamera(from: presentedVC)
            }
            cameraAction.setValue(UIColor.systemBlue, forKey: "titleTextColor")

            let galleryAction = UIAlertAction(title: labelGallery, style: .default) { _ in
                self.isHandlingAlertAction = true
                self.openGallery(from: presentedVC)
            }
            galleryAction.setValue(UIColor.systemBlue, forKey: "titleTextColor")

            let cancelAction = UIAlertAction(title: labelCancel, style: .cancel) { _ in
                self.finish(nil)
            }
            cancelAction.setValue(UIColor.systemRed, forKey: "titleTextColor")
            
            alertController.addAction(cameraAction)
            alertController.addAction(galleryAction)
            alertController.addAction(cancelAction)
            
            if UIDevice.current.userInterfaceIdiom == .pad,
               let popoverController = alertController.popoverPresentationController {
                popoverController.sourceView = presentedVC.view
                let midX = presentedVC.view.bounds.midX
                let midY = presentedVC.view.bounds.midY
                popoverController.sourceRect = CGRect(x: midX, y: midY, width: 0, height: 0)
                popoverController.permittedArrowDirections = []

                // On iPad the sheet is a popover, which the user can dismiss by tapping outside
                // without the cancel action ever running. That would strand the result callback
                // and, because a second call is rejected as ALREADY_ACTIVE, lock the plugin for
                // the rest of the process. UIKit also invokes this delegate for the dismissal that
                // follows choosing Camera or Gallery, not only for a tap-outside/swipe dismissal, so
                // `isHandlingAlertAction` distinguishes the two: it is set right before those actions
                // present their own flow, and checked (then cleared) here so that legitimate case is
                // ignored while a real user-driven dismissal still finishes with `nil`.
                //
                // The delegate is set only here, on the popover. On iPhone the sheet uses UIKit's
                // alert presentation controller, which raises NSInternalInconsistencyException if
                // its delegate is replaced, and it cannot be dismissed without choosing an action.
                popoverController.delegate = self
            }

            // Only the popover delegate above ever clears this flag, so a value left over from an
            // earlier sheet must not leak into this one.
            isHandlingAlertAction = false

            presentedVC.present(alertController, animated: true)
        }
    }

    /// Runs `onGranted` once camera access is available, failing the call otherwise.
    ///
    /// This is the same `AVCaptureDevice` API the `permission_handler` package wrapped for
    /// `Permission.camera`, called directly so the plugin carries no permission dependency.
    /// Asking here rather than from Dart also means flows that never open the camera
    /// (`ScannerSource.gallery`, which uses the out-of-process photo picker) prompt for nothing.
    func withCameraAccess(_ onGranted: @escaping () -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            onGranted()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                // The completion handler runs on an arbitrary queue; presenting needs the main one.
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if granted {
                        onGranted()
                    } else {
                        self.finishWithPermissionDenied()
                    }
                }
            }
        // `.restricted` covers parental controls and MDM policy. It used to slip through the
        // Dart-side check and open a camera the user could never grant access to.
        case .denied, .restricted:
            finishWithPermissionDenied()
        @unknown default:
            finishWithPermissionDenied()
        }
    }

    /// Fails the pending call with the permission error contract documented for Dart.
    private func finishWithPermissionDenied() {
        finish(FlutterError(
            code: "permission_denied",
            message: "Camera permission not granted",
            details: nil
        ))
    }

    /// Launches the native system document camera (VNDocumentCameraViewController).
    func openCamera(from presentedVC: UIViewController) {
        withCameraAccess { [weak self] in
            guard let self = self else { return }

            guard VNDocumentCameraViewController.isSupported else {
                let errorMsg = "Document camera is not available on this device"
                self.finish(FlutterError(code: "UNAVAILABLE", message: errorMsg, details: nil))
                return
            }

            let controller = VNDocumentCameraViewController()
            controller.delegate = self
            self.presentingController = controller
            presentedVC.present(controller, animated: true)
        }
    }

    /// Launches the photo picker (PHPickerViewController on iOS 14+, fallback to UIImagePickerController).
    func openGallery(from presentedVC: UIViewController) {
        presentedVC.present(makeGalleryPicker(), animated: true)
    }

    /// Builds the photo picker for the current options, wired so that every way of closing it
    /// delivers the result.
    func makeGalleryPicker() -> UIViewController {
        if #available(iOS 14.0, *) {
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = scannerOptions.noOfPages

            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            // The picker is a sheet, and swiping it down slowly dismisses it without
            // `picker(_:didFinishPicking:)` running, which would strand the result and reject
            // every later scan as ALREADY_ACTIVE. `presentationControllerDidDismiss` catches it.
            picker.presentationController?.delegate = self
            return picker
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            // Sheet-style presentation lets the user swipe this picker away without
            // `imagePickerControllerDidCancel` running, which would strand the result.
            picker.modalPresentationStyle = .fullScreen
            return picker
        }
    }

    /// Clears the files this plugin created, and only those.
    ///
    /// Everything the plugin writes lives inside a private subdirectory of the app's
    /// caches directory, so cleaning is a matter of removing that one directory. Files
    /// belonging to the host application are never touched.
    func cleanCache(result: FlutterResult) {
        let fileManager = FileManager.default
        let storageDir = getScanStorageDirectory()
        do {
            if fileManager.fileExists(atPath: storageDir.path) {
                try fileManager.removeItem(at: storageDir)
            }
            result(nil)
        } catch {
            result(FlutterError(code: "CLEAN_CACHE_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    /// The private directory where scans and generated PDFs are written.
    ///
    /// A dedicated subdirectory of `Library/Caches` is used rather than the app's
    /// `Documents` directory: these files are regenerable scratch output, they must not
    /// be backed up to iCloud, and keeping them isolated makes `cleanCache()` incapable
    /// of deleting host application data.
    func getScanStorageDirectory() -> URL {
        let fileManager = FileManager.default
        let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let storageDir = cachesDir.appendingPathComponent(Self.storageDirectoryName, isDirectory: true)
        if !fileManager.fileExists(atPath: storageDir.path) {
            try? fileManager.createDirectory(at: storageDir, withIntermediateDirectories: true)
        }
        return storageDir
    }

    /// The bundle holding the plugin's translations.
    ///
    /// Swift Package Manager generates `Bundle.module`. CocoaPods builds the
    /// `cunning_document_scanner_resources` bundle declared in the podspec, which sits inside
    /// the plugin framework, or inside the app itself when the pod is linked statically.
    static let resourceBundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        let codeBundle = Bundle(for: CunningDocumentScannerPlugin.self)
        guard let url = codeBundle.url(forResource: "cunning_document_scanner_resources", withExtension: "bundle"),
              let bundle = Bundle(url: url) else {
            return codeBundle
        }
        return bundle
        #endif
    }()

    /// Helper to fetch localized string translations for keys, falling back to a default value.
    func getLocalizedOption(_ key: String, defaultValue: String) -> String {
        let mainBundleValue = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        if mainBundleValue != key {
            return mainBundleValue
        }
        let pluginBundle = Self.resourceBundle

        var resolvedBundle = pluginBundle
        search: for language in pluginLanguagePreferences {
            // Tries the full identifier first and then drops trailing components, so that
            // `zh-Hans-ES` resolves to `zh-Hans.lproj` and `pt-BR` to `pt.lproj`.
            var components = language.components(separatedBy: "-")
            while !components.isEmpty {
                if let path = pluginBundle.path(forResource: components.joined(separator: "-"), ofType: "lproj"),
                   let langBundle = Bundle(path: path) {
                    resolvedBundle = langBundle
                    break search
                }
                components.removeLast()
            }
        }

        return resolvedBundle.localizedString(forKey: key, value: defaultValue, table: nil)
    }

    /// The languages the plugin's own strings are resolved against, most preferred first.
    ///
    /// Apple's document camera is shown in the language the host application resolves to, so
    /// the plugin follows the same rule to keep every screen of a scan in one language, set from
    /// a single place in the application's `Info.plist`. With `CFBundleAllowMixedLocalizations`
    /// the system screens follow the device languages, and so does the plugin. Otherwise both use
    /// the application's own resolved localization, which `CFBundleLocalizations` controls.
    private var pluginLanguagePreferences: [String] {
        let allowsMixedLocalizations = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleAllowMixedLocalizations"
        ) as? Bool ?? false
        if allowsMixedLocalizations {
            return Locale.preferredLanguages
        }
        return Bundle.main.preferredLocalizations.filter { $0 != "Base" }
    }

    /// Presents the custom cropper for the given images, configured from the current options.
    func presentCropper(with images: [UIImage]) {
        let cropper = CunningDocumentCropperViewController(
            images: images,
            defaultFilter: scannerOptions.defaultFilter,
            showFilterBar: scannerOptions.showFilterBar
        ) { [weak self] key, dValue in
            return self?.getLocalizedOption(key, defaultValue: dValue) ?? dValue
        }
        cropper.delegate = self
        cropper.modalPresentationStyle = .fullScreen
        rootViewController?.present(cropper, animated: true)
    }

    /// Delivers a value to Flutter exactly once and releases the pending result callback.
    ///
    /// Every exit path of a `scanDocuments` flow funnels through here so the callback can
    /// never be invoked twice (which traps) nor left dangling (which would block the next call).
    func finish(_ value: Any?) {
        guard let channel = resultChannel else { return }
        resultChannel = nil
        channel(value)
    }

    /// Writes the pages as image files, a PDF, or both, and returns the result to Flutter.
    func processSelectedImages(_ images: [UIImage]) {
        let storageDir = getScanStorageDirectory()
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let baseName = "\(Self.scanFilePrefix)\(df.string(from: Date()))"

        var pdfPath: String?
        if scannerOptions.output.wantsPdf {
            let pdfDocument = PDFDocument()
            for (i, pageImage) in images.enumerated() {
                if let pdfPage = PDFPage(image: pageImage) {
                    pdfDocument.insert(pdfPage, at: i)
                }
            }
            let url = storageDir.appendingPathComponent("\(baseName).pdf")
            guard pdfDocument.write(to: url) else {
                finish(FlutterError(code: "ERROR", message: "Failed to generate PDF document", details: nil))
                return
            }
            pdfPath = url.path
        }

        var filenames: [String] = []
        if scannerOptions.output.wantsImages {
            do {
                for (i, page) in images.enumerated() {
                    let ext = scannerOptions.imageFormat.rawValue
                    let url = storageDir.appendingPathComponent("\(baseName)-\(i).\(ext)")

                    let data: Data?
                    switch scannerOptions.imageFormat {
                    case .jpg:
                        data = page.jpegData(compressionQuality: scannerOptions.jpgCompressionQuality)
                    case .png:
                        data = page.pngData()
                    }

                    guard let imageData = data else {
                        throw CunningScannerError.encodingFailed(page: i)
                    }
                    // Write failures used to be swallowed, handing Flutter paths to files
                    // that were never created. They are surfaced as errors instead.
                    try imageData.write(to: url)
                    filenames.append(url.path)
                }
            } catch {
                finish(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
                return
            }
        }

        var result: [String: Any] = [
            "images": filenames,
            "discardedPages": discardedPages
        ]
        // Left out rather than set to nil: a missing key reads as null on the Dart side.
        if let pdfPath = pdfPath {
            result["pdf"] = pdfPath
        }
        finish(result)
    }

    // MARK: - VNDocumentCameraViewControllerDelegate

    /// Delegate callback for camera scans. Receives pages and processes them up to scannerOptions.noOfPages.
    public func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFinishWith scan: VNDocumentCameraScan
    ) {
        var images: [UIImage] = []
        let pages = scannerOptions.pageSplit(forScanned: scan.pageCount)
        discardedPages = pages.discarded
        for i in 0 ..< pages.kept {
            images.append(scan.imageOfPage(at: i))
        }
        processSelectedImages(images)
        presentingController?.dismiss(animated: true)
    }

    /// Delegate callback for cancelled camera scans.
    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        finish(nil)
        presentingController?.dismiss(animated: true)
    }

    /// Delegate callback for camera scan failures.
    public func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFailWithError error: Error
    ) {
        finish(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
        presentingController?.dismiss(animated: true)
    }

    // MARK: - UIImagePickerControllerDelegate

    /// Delegate callback for picking media (legacy UIImagePickerController).
    public func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        guard let image = info[.originalImage] as? UIImage else {
            picker.dismiss(animated: true) {
                self.finish(nil)
            }
            return
        }
        
        let downscaledImage = image.downscaled(toMaxDimension: 2048)
        
        picker.dismiss(animated: true) {
            self.presentCropper(with: [downscaledImage])
        }
    }

    /// Delegate callback for legacy picker cancellations.
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            self.finish(nil)
        }
    }
}

// MARK: - PHPickerViewControllerDelegate

@available(iOS 14.0, *)
extension CunningDocumentScannerPlugin: PHPickerViewControllerDelegate {
    
    /// Delegate callback for picking media with the modern PHPickerViewController.
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        if results.isEmpty {
            picker.dismiss(animated: true) {
                self.finish(nil)
            }
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var images: [UIImage] = Array(repeating: UIImage(), count: results.count)
        
        for (index, result) in results.enumerated() where result.itemProvider.canLoadObject(ofClass: UIImage.self) {
            dispatchGroup.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { (object, _) in
                if let image = object as? UIImage {
                    let downscaled = image.downscaled(toMaxDimension: 2048)
                    DispatchQueue.main.async {
                        images[index] = downscaled
                        dispatchGroup.leave()
                    }
                } else {
                    DispatchQueue.main.async {
                        dispatchGroup.leave()
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            let loadedImages = images.filter { $0.size.width > 0 }
            let pages = self.scannerOptions.pageSplit(forScanned: loadedImages.count)
            self.discardedPages = pages.discarded
            let validImages = Array(loadedImages.prefix(pages.kept))
            if validImages.isEmpty {
                picker.dismiss(animated: true) {
                    self.finish(nil)
                }
            } else {
                picker.dismiss(animated: true) {
                    self.presentCropper(with: validImages)
                }
            }
        }
    }
}

// MARK: - UIPopoverPresentationControllerDelegate

extension CunningDocumentScannerPlugin: UIPopoverPresentationControllerDelegate {

    /// Treats a user-driven dismissal of the photo picker sheet or the iPad popover as a
    /// cancellation.
    ///
    /// For the popover, UIKit calls this both for a tap outside it and for the dismissal that
    /// follows tapping Camera or Gallery, so `isHandlingAlertAction` is checked to ignore the
    /// latter. The picker skips that check: the flag is still set from choosing Gallery, since
    /// on iPhone nothing clears it, and the picker only reaches here when swiped away.
    /// `finish` is a no-op once the result has already been delivered.
    public func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        if #available(iOS 14.0, *), presentationController.presentedViewController is PHPickerViewController {
            finish(nil)
            return
        }
        if isHandlingAlertAction {
            isHandlingAlertAction = false
            return
        }
        finish(nil)
    }
}

// MARK: - CunningDocumentCropperDelegate

extension CunningDocumentScannerPlugin: CunningDocumentCropperDelegate {
    
    /// Handles completion of cropping flow. Passes cropped results to the file output processor.
    func didFinishCropping(croppedImages: [UIImage]) {
        rootViewController?.dismiss(animated: true) {
            self.processSelectedImages(croppedImages)
        }
    }
    
    /// Handles cancel/abort events from the cropper view controller.
    func didCancelCropping() {
        rootViewController?.dismiss(animated: true) {
            self.finish(nil)
        }
    }
}
