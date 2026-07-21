import Flutter
import UIKit
import Vision
import VisionKit
import PDFKit
import Photos
import PhotosUI

/// Main iOS plugin class for cunning_document_scanner.
/// Handles Flutter MethodChannel calls to launch camera or photo gallery scanning flows.
public class CunningDocumentScannerPlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    /// The Flutter channel result callback pointer to return document paths to Dart/Flutter.
    var resultChannel: FlutterResult?
    
    /// The native VNDocumentCameraViewController presenting instance.
    var presentingController: VNDocumentCameraViewController?
    
    /// The options passed from the Dart/Flutter side.
    var scannerOptions = CunningScannerOptions()

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

    /// Handles incoming FlutterMethodCalls. Specifically listens to "getPictures" and "cleanCache" methods.
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "cleanCache" {
            self.cleanCache(result: result)
            return
        }

        guard call.method == "getPictures" else {
            result(FlutterMethodNotImplemented)
            return
        }

        scannerOptions = CunningScannerOptions.fromArguments(args: call.arguments)
        let presentedVC = rootViewController
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
                self.openCamera(from: presentedVC)
            }
            cameraAction.setValue(UIColor.systemBlue, forKey: "titleTextColor")

            let galleryAction = UIAlertAction(title: labelGallery, style: .default) { _ in
                self.openGallery(from: presentedVC)
            }
            galleryAction.setValue(UIColor.systemBlue, forKey: "titleTextColor")

            let cancelAction = UIAlertAction(title: labelCancel, style: .cancel) { _ in
                self.resultChannel?(nil)
            }
            cancelAction.setValue(UIColor.systemRed, forKey: "titleTextColor")
            
            alertController.addAction(cameraAction)
            alertController.addAction(galleryAction)
            alertController.addAction(cancelAction)
            
            if UIDevice.current.userInterfaceIdiom == .pad,
               let popoverController = alertController.popoverPresentationController {
                popoverController.sourceView = presentedVC?.view
                popoverController.sourceRect = CGRect(x: presentedVC?.view.bounds.midX ?? 0, y: presentedVC?.view.bounds.midY ?? 0, width: 0, height: 0)
                popoverController.permittedArrowDirections = []
            }
            
            presentedVC?.present(alertController, animated: true)
        }
    }

    /// Launches the native system document camera (VNDocumentCameraViewController).
    func openCamera(from presentedVC: UIViewController?) {
        if VNDocumentCameraViewController.isSupported {
            presentingController = VNDocumentCameraViewController()
            presentingController?.delegate = self
            presentedVC?.present(presentingController!, animated: true)
        } else {
            resultChannel?(FlutterError(code: "UNAVAILABLE", message: "Document camera is not available on this device", details: nil))
        }
    }

    /// Launches the photo picker (PHPickerViewController on iOS 14+, fallback to UIImagePickerController).
    func openGallery(from presentedVC: UIViewController?) {
        if #available(iOS 14.0, *) {
            var configuration = PHPickerConfiguration()
            configuration.filter = .images
            configuration.selectionLimit = scannerOptions.noOfPages
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = self
            presentedVC?.present(picker, animated: true)
        } else {
            let picker = UIImagePickerController()
            picker.sourceType = .photoLibrary
            picker.delegate = self
            presentedVC?.present(picker, animated: true)
        }
    }

    /// Clears temporary scan files (.pdf, .jpg, .png) created by the plugin from local documents directory.
    func cleanCache(result: FlutterResult) {
        let fileManager = FileManager.default
        let docDir = getDocumentsDirectory()
        do {
            let files = try fileManager.contentsOfDirectory(atPath: docDir.path)
            for file in files {
                if file.hasSuffix(".pdf") || file.hasSuffix(".jpg") || file.hasSuffix(".png") {
                    let filePath = docDir.appendingPathComponent(file)
                    try fileManager.removeItem(at: filePath)
                }
            }
            result(nil)
        } catch {
            result(FlutterError(code: "CLEAN_CACHE_ERROR", message: error.localizedDescription, details: nil))
        }
    }

    /// Helper to retrieve the app's documents directory URL.
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    /// Helper to fetch localized string translations for keys, falling back to a default value.
    func getLocalizedOption(_ key: String, defaultValue: String) -> String {
        let mainBundleValue = Bundle.main.localizedString(forKey: key, value: nil, table: nil)
        if mainBundleValue != key {
            return mainBundleValue
        }
        #if SWIFT_PACKAGE
        let pluginBundle = Bundle.module
        #else
        let pluginBundle = Bundle(for: CunningDocumentScannerPlugin.self)
        #endif

        var resolvedBundle = pluginBundle
        for language in Locale.preferredLanguages {
            let baseLanguage = language.components(separatedBy: "-").first ?? language
            if let path = pluginBundle.path(forResource: baseLanguage, ofType: "lproj"),
               let langBundle = Bundle(path: path) {
                resolvedBundle = langBundle
                break
            }
        }

        return resolvedBundle.localizedString(forKey: key, value: defaultValue, table: nil)
    }

    /// Writes scanned or cropped images to local files (or compiles them to a single PDF) and returns paths to Flutter.
    func processSelectedImages(_ images: [UIImage]) {
        let tempDirPath = getDocumentsDirectory()
        let currentDateTime = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let formattedDate = df.string(from: currentDateTime)

        if scannerOptions.asPdf {
            let pdfDocument = PDFDocument()
            for (i, pageImage) in images.enumerated() {
                if let pdfPage = PDFPage(image: pageImage) {
                    pdfDocument.insert(pdfPage, at: i)
                }
            }
            let url = tempDirPath.appendingPathComponent(formattedDate + ".pdf")
            if pdfDocument.write(to: url) {
                resultChannel?([url.path])
            } else {
                resultChannel?(FlutterError(code: "ERROR", message: "Failed to generate PDF document", details: nil))
            }
        } else {
            var filenames: [String] = []
            for (i, page) in images.enumerated() {
                let url = tempDirPath.appendingPathComponent(formattedDate + "-\(i).\(scannerOptions.imageFormat.rawValue)")

                switch scannerOptions.imageFormat {
                case .jpg:
                    try? page.jpegData(compressionQuality: scannerOptions.jpgCompressionQuality)?.write(to: url)
                case .png:
                    try? page.pngData()?.write(to: url)
                }

                filenames.append(url.path)
            }
            resultChannel?(filenames)
        }
    }

    // MARK: - VNDocumentCameraViewControllerDelegate

    /// Delegate callback for camera scans. Receives pages and processes them directly up to scannerOptions.noOfPages.
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        var images: [UIImage] = []
        let maxPages = min(scan.pageCount, scannerOptions.noOfPages)
        for i in 0 ..< maxPages {
            images.append(scan.imageOfPage(at: i))
        }
        processSelectedImages(images)
        presentingController?.dismiss(animated: true)
    }

    /// Delegate callback for cancelled camera scans.
    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        resultChannel?(nil)
        presentingController?.dismiss(animated: true)
    }

    /// Delegate callback for camera scan failures.
    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        resultChannel?(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
        presentingController?.dismiss(animated: true)
    }

    // MARK: - UIImagePickerControllerDelegate

    /// Delegate callback for picking media (legacy UIImagePickerController).
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        guard let image = info[.originalImage] as? UIImage else {
            picker.dismiss(animated: true) {
                self.resultChannel?(nil)
            }
            return
        }
        
        let downscaledImage = image.downscaled(toMaxDimension: 2048)
        
        picker.dismiss(animated: true) {
            let cropper = CunningDocumentCropperViewController(images: [downscaledImage]) { [weak self] key, defaultValue in
                return self?.getLocalizedOption(key, defaultValue: defaultValue) ?? defaultValue
            }
            cropper.delegate = self
            cropper.modalPresentationStyle = .fullScreen
            self.rootViewController?.present(cropper, animated: true)
        }
    }

    /// Delegate callback for legacy picker cancellations.
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            self.resultChannel?(nil)
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
                self.resultChannel?(nil)
            }
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var images: [UIImage] = Array(repeating: UIImage(), count: results.count)
        
        for (index, result) in results.enumerated() {
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                dispatchGroup.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
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
        }
        
        dispatchGroup.notify(queue: .main) {
            var validImages = images.filter { $0.size.width > 0 }
            if validImages.count > self.scannerOptions.noOfPages {
                validImages = Array(validImages.prefix(self.scannerOptions.noOfPages))
            }
            if validImages.isEmpty {
                picker.dismiss(animated: true) {
                    self.resultChannel?(nil)
                }
            } else {
                picker.dismiss(animated: true) {
                    let cropper = CunningDocumentCropperViewController(images: validImages) { [weak self] key, defaultValue in
                        return self?.getLocalizedOption(key, defaultValue: defaultValue) ?? defaultValue
                    }
                    cropper.delegate = self
                    cropper.modalPresentationStyle = .fullScreen
                    self.rootViewController?.present(cropper, animated: true)
                }
            }
        }
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
            self.resultChannel?(nil)
        }
    }
}
