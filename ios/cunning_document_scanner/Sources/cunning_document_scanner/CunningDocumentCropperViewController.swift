import UIKit
import Vision
import CoreImage

/// Delegate protocol for CunningDocumentCropperViewController to notify its parent of cropping completion or cancellation.
protocol CunningDocumentCropperDelegate: AnyObject {
    /// Called when the user has successfully finished cropping all selected images.
    /// - Parameter croppedImages: An array of final cropped and perspective-corrected images.
    func didFinishCropping(croppedImages: [UIImage])
    
    /// Called when the user cancels the cropping flow.
    func didCancelCropping()
}

/// View controller that provides an interactive multi-page document cropping interface.
/// It displays selected images and overlays draggable handles to correct perspective skewing.
class CunningDocumentCropperViewController: UIViewController {
    
    /// The delegate to handle cropping lifecycle events.
    weak var delegate: CunningDocumentCropperDelegate?
    
    /// The array of original images to be cropped.
    private var images: [UIImage] = []
    
    /// The array of output cropped images populated during the flow.
    private var croppedImages: [UIImage] = []
    
    /// The index of the current page being cropped.
    private var currentIndex = 0
    
    /// The UIImageView to display the page image.
    private let imageView = UIImageView()
    
    /// The overlay canvas containing handles and drawing the crop boundaries.
    private let overlayView = CroppingOverlayView()
    
    /// The top navigation bar view.
    private let topBar = UIView()
    
    /// The bottom control bar view.
    private let bottomBar = UIView()
    
    /// The label showing page progress (e.g. "Crop Page 1 of 3").
    private let titleLabel = UILabel()
    
    /// The button to dismiss the cropping view.
    private let cancelButton = UIButton(type: .system)
    
    /// The button to advance to the next page or finish.
    private let doneButton = UIButton(type: .system)
    
    /// The button to rotate the current page clockwise.
    private let rotateButton = UIButton(type: .system)
    
    /// The back button to return to the previous page.
    private let backButton = UIButton(type: .system)
    
    /// The activity spinner shown during background image loading/processing.
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    
    /// The CoreImage context used to execute perspective correction filters.
    private let ciContext = CIContext(options: nil)
    
    /// A structure representing normalized corner coordinates of a page (0.0 to 1.0, bottom-left origin).
    private struct PageCoordinates {
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomLeft: CGPoint
        let bottomRight: CGPoint
    }
    
    /// A list mapping page indexes to their last saved/detected cropping coordinates.
    private var savedCoordinates: [PageCoordinates?] = []
    
    /// Indicates whether the initial corner points have been set up for the current page.
    private var hasSetupPoints = false
    
    /// Indicates whether the user has interacted with the corner handles.
    private var hasUserModifiedPoints = false
    
    /// The current image under review with fixed orientation.
    private var currentNormalizedImage: UIImage?
    
    /// A closure used to retrieve localized option strings from the main plugin.
    private let localize: (String, String) -> String
    
    // Normalized coordinates (origin at bottom-left)
    private var normTopLeft = CGPoint(x: 0.15, y: 0.85)
    private var normTopRight = CGPoint(x: 0.85, y: 0.85)
    private var normBottomLeft = CGPoint(x: 0.15, y: 0.15)
    private var normBottomRight = CGPoint(x: 0.85, y: 0.15)
    
    /// Initializes a new cropper view controller with a list of images and a localizer.
    /// - Parameters:
    ///   - images: The list of raw images to crop.
    ///   - localize: A closure to retrieve localized translation strings.
    init(images: [UIImage], localize: @escaping (String, String) -> String) {
        self.localize = localize
        self.images = images
        super.init(nibName: nil, bundle: nil)
        self.savedCoordinates = Array(repeating: nil, count: images.count)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupViews()
        setupConstraints()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        let frame = getContentFrame()
        overlayView.contentFrame = frame
        
        if !hasSetupPoints && currentIndex < images.count {
            hasSetupPoints = true
            detectAndSetupPoints()
        } else {
            updateHandlesToMatchNormalizedPoints()
        }
    }
    
    /// Sets up and configures subviews and actions.
    private func setupViews() {
        // Image View configuration
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        view.addSubview(imageView)
        
        // Overlay View configuration
        overlayView.onPointsChanged = { [weak self] in
            guard let self = self else { return }
            self.hasUserModifiedPoints = true
            let frame = self.getContentFrame()
            self.normTopLeft = self.overlayView.normalizedPoint(fromView: self.overlayView.topLeft, contentFrame: frame)
            self.normTopRight = self.overlayView.normalizedPoint(fromView: self.overlayView.topRight, contentFrame: frame)
            self.normBottomLeft = self.overlayView.normalizedPoint(fromView: self.overlayView.bottomLeft, contentFrame: frame)
            self.normBottomRight = self.overlayView.normalizedPoint(fromView: self.overlayView.bottomRight, contentFrame: frame)
        }
        view.addSubview(overlayView)
        
        // Activity Indicator configuration
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
        view.addSubview(activityIndicator)
        
        // Top Bar configuration
        topBar.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.addSubview(topBar)
        
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textAlignment = .center
        topBar.addSubview(titleLabel)
        
        // Bottom Bar configuration
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.addSubview(bottomBar)
        
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        
        cancelButton.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        cancelButton.tintColor = .white
        cancelButton.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        cancelButton.layer.cornerRadius = 22
        cancelButton.clipsToBounds = true
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        bottomBar.addSubview(cancelButton)
        
        doneButton.layer.cornerRadius = 22
        doneButton.clipsToBounds = true
        doneButton.addTarget(self, action: #selector(handleDone), for: .touchUpInside)
        bottomBar.addSubview(doneButton)
        
        rotateButton.setImage(UIImage(systemName: "rotate.right", withConfiguration: config), for: .normal)
        rotateButton.tintColor = .white
        rotateButton.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        rotateButton.layer.cornerRadius = 22
        rotateButton.clipsToBounds = true
        rotateButton.addTarget(self, action: #selector(handleRotate), for: .touchUpInside)
        bottomBar.addSubview(rotateButton)
        
        // Back Button configuration (top-left)
        backButton.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        backButton.tintColor = .white
        backButton.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        backButton.layer.cornerRadius = 22
        backButton.clipsToBounds = true
        backButton.addTarget(self, action: #selector(handleBack), for: .touchUpInside)
        topBar.addSubview(backButton)
        
        loadCurrentImage()
    }
    
    /// Activates Auto Layout constraints for the interface components.
    private func setupConstraints() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        topBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        rotateButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Back Button (Top Bar left)
            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 15),
            backButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Activity Indicator
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // Top Bar
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 50),
            
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: topBar.trailingAnchor, constant: -12),
            
            // Bottom Bar
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 60),
            
            cancelButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 20),
            cancelButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 44),
            cancelButton.heightAnchor.constraint(equalToConstant: 44),
            
            doneButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -20),
            doneButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            doneButton.widthAnchor.constraint(equalToConstant: 44),
            doneButton.heightAnchor.constraint(equalToConstant: 44),
            
            rotateButton.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            rotateButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            rotateButton.widthAnchor.constraint(equalToConstant: 44),
            rotateButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Image View (fills space between top and bottom bar)
            imageView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Overlay View covers image view exactly
            overlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor)
        ])
    }
    
    /// Loads and processes the image corresponding to the current index.
    /// Normalizes orientation on a global background thread prior to displaying.
    private func loadCurrentImage() {
        guard currentIndex < images.count else { return }
        
        let imageToProcess = images[currentIndex]
        
        // Show spinner and temporarily disable controls
        activityIndicator.startAnimating()
        doneButton.isEnabled = false
        rotateButton.isEnabled = false
        cancelButton.isEnabled = false
        backButton.isEnabled = false
        
        // Update Title and Done Button Label
        let pageNum = currentIndex + 1
        let titleFormat = localize("cunning_document_scanner_crop_title", "Crop Page %d of %d")
        titleLabel.text = String(format: titleFormat, pageNum, images.count)
        
        let isLastPage = (currentIndex == images.count - 1)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        let doneImageName = isLastPage ? "checkmark" : "arrow.right"
        let doneImage = UIImage(systemName: doneImageName, withConfiguration: config)
        doneButton.setImage(doneImage, for: .normal)
        doneButton.tintColor = .white
        doneButton.backgroundColor = .systemBlue
        
        // Show/hide back button based on page index
        backButton.isHidden = (currentIndex == 0)
        
        // Perform fixedOrientation on a background thread with an autoreleasepool to save memory
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var fixedImage: UIImage?
            autoreleasepool {
                fixedImage = imageToProcess.fixedOrientation()
            }
            
            DispatchQueue.main.async {
                // Ensure the user hasn't switched pages while we were processing
                guard self.currentIndex < self.images.count, self.images[self.currentIndex] === imageToProcess else {
                    return
                }
                
                guard let resolvedImage = fixedImage else {
                    self.activityIndicator.stopAnimating()
                    self.doneButton.isEnabled = true
                    self.rotateButton.isEnabled = true
                    self.cancelButton.isEnabled = true
                    self.backButton.isEnabled = !self.backButton.isHidden
                    return
                }
                
                self.currentNormalizedImage = resolvedImage
                self.imageView.image = resolvedImage
                
                self.activityIndicator.stopAnimating()
                self.doneButton.isEnabled = true
                self.rotateButton.isEnabled = true
                self.cancelButton.isEnabled = true
                self.backButton.isEnabled = !self.backButton.isHidden
                
                // Restore coordinates if previously saved, otherwise run auto-detection
                if let saved = self.savedCoordinates[self.currentIndex] {
                    self.normTopLeft = saved.topLeft
                    self.normTopRight = saved.topRight
                    self.normBottomLeft = saved.bottomLeft
                    self.normBottomRight = saved.bottomRight
                    self.hasSetupPoints = true
                    self.hasUserModifiedPoints = true
                } else {
                    self.hasSetupPoints = false
                    self.hasUserModifiedPoints = false
                }
                self.view.setNeedsLayout()
            }
        }
    }
    
    /// Detects document boundary coordinates asynchronously using Vision Framework (iOS 15.0+),
    /// defaulting to a standard inset box if detection fails or is unavailable.
    private func detectAndSetupPoints() {
        guard currentIndex < images.count else { return }
        guard let currentImage = self.currentNormalizedImage else { return }
        
        // Set default points initially
        self.normTopLeft = CGPoint(x: 0.15, y: 0.85)
        self.normTopRight = CGPoint(x: 0.85, y: 0.85)
        self.normBottomLeft = CGPoint(x: 0.15, y: 0.15)
        self.normBottomRight = CGPoint(x: 0.85, y: 0.15)
        
        self.updateHandlesToMatchNormalizedPoints()
        
        if #available(iOS 15.0, *) {
            // Run vision detection asynchronously
            guard let cgImage = currentImage.cgImage else { return }
            let requestIndex = self.currentIndex
            let request = VNDetectDocumentSegmentationRequest { [weak self] request, error in
                guard let self = self else { return }
                guard error == nil,
                      let results = request.results as? [VNRectangleObservation],
                      let firstResult = results.first else {
                    return // Use defaults
                }
                
                DispatchQueue.main.async {
                    // Verify we are still on the same image and user hasn't modified points manually
                    guard self.currentIndex == requestIndex, !self.hasUserModifiedPoints else { return }
                    self.normTopLeft = firstResult.topLeft
                    self.normTopRight = firstResult.topRight
                    self.normBottomLeft = firstResult.bottomLeft
                    self.normBottomRight = firstResult.bottomRight
                    self.updateHandlesToMatchNormalizedPoints()
                }
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                try? handler.perform([request])
            }
        }
    }
    
    /// Updates the overlay view's handle positions to match current normalized coordinate variables.
    private func updateHandlesToMatchNormalizedPoints() {
        let frame = getContentFrame()
        overlayView.topLeft = overlayView.viewPoint(fromNormalized: normTopLeft, contentFrame: frame)
        overlayView.topRight = overlayView.viewPoint(fromNormalized: normTopRight, contentFrame: frame)
        overlayView.bottomLeft = overlayView.viewPoint(fromNormalized: normBottomLeft, contentFrame: frame)
        overlayView.bottomRight = overlayView.viewPoint(fromNormalized: normBottomRight, contentFrame: frame)
        overlayView.updateHandlePositions()
    }
    
    /// Calculates the size and origin of the aspect-fit image as it appears inside the UIImageView.
    private func getContentFrame() -> CGRect {
        guard let image = imageView.image else { return .zero }
        let imgSize = image.size
        let viewSize = imageView.bounds.size
        
        guard imgSize.width > 0 && imgSize.height > 0 && viewSize.width > 0 && viewSize.height > 0 else {
            return .zero
        }
        
        let wRatio = viewSize.width / imgSize.width
        let hRatio = viewSize.height / imgSize.height
        let scale = min(wRatio, hRatio)
        
        let contentW = imgSize.width * scale
        let contentH = imgSize.height * scale
        let x = (viewSize.width - contentW) / 2.0
        let y = (viewSize.height - contentH) / 2.0
        
        return CGRect(x: x, y: y, width: contentW, height: contentH)
    }
    
    /// Responds to cancel actions, prompting a discard confirmation alert if modifications are present.
    @objc private func handleCancel() {
        let hasChanges = hasUserModifiedPoints || currentIndex > 0
        if hasChanges {
            let alertTitle = localize("cunning_document_scanner_discard_title", "Discard changes?")
            let alertMessage = localize("cunning_document_scanner_discard_message", "Are you sure you want to discard your progress?")
            let cancelText = localize("cunning_document_scanner_cancel", "Cancel")
            let discardText = localize("cunning_document_scanner_discard", "Discard")
            
            let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: cancelText, style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: discardText, style: .destructive, handler: { [weak self] _ in
                self?.delegate?.didCancelCropping()
            }))
            present(alert, animated: true, completion: nil)
        } else {
            delegate?.didCancelCropping()
        }
    }
    
    /// Confirms selection of current page crop, performs perspective correction, and advances progress.
    @objc private func handleDone() {
        guard currentIndex < images.count else { return }
        guard let currentImage = self.currentNormalizedImage else { return }
        
        // Save current coordinates
        self.savedCoordinates[currentIndex] = PageCoordinates(
            topLeft: self.normTopLeft,
            topRight: self.normTopRight,
            bottomLeft: self.normBottomLeft,
            bottomRight: self.normBottomRight
        )
        
        // Show spinner / block buttons to prevent double-tap
        cancelButton.isEnabled = false
        doneButton.isEnabled = false
        rotateButton.isEnabled = false
        backButton.isEnabled = false
        activityIndicator.startAnimating()
        
        // Crop the current image on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var cropped: UIImage?
            autoreleasepool {
                cropped = self.cropImage(
                    image: currentImage,
                    topLeft: self.normTopLeft,
                    topRight: self.normTopRight,
                    bottomLeft: self.normBottomLeft,
                    bottomRight: self.normBottomRight
                )
            }
            
            let finalImage: UIImage
            if let cropped = cropped {
                finalImage = cropped
            } else {
                // Fallback to original image with orientation fixed/baked in
                var fixed: UIImage?
                autoreleasepool {
                    fixed = currentImage.fixedOrientation()
                }
                finalImage = fixed ?? currentImage
            }
            
            DispatchQueue.main.async {
                self.cancelButton.isEnabled = true
                self.doneButton.isEnabled = true
                self.rotateButton.isEnabled = true
                self.backButton.isEnabled = true
                self.activityIndicator.stopAnimating()
                
                self.croppedImages.append(finalImage)
                
                self.currentIndex += 1
                if self.currentIndex < self.images.count {
                    self.loadCurrentImage()
                } else {
                    self.delegate?.didFinishCropping(croppedImages: self.croppedImages)
                }
            }
        }
    }
    
    /// Rotates the image metadata and corner crop coordinates 90 degrees clockwise instantly.
    @objc private func handleRotate() {
        guard currentIndex < images.count else { return }
        guard let currentImage = self.currentNormalizedImage else { return }
        
        if let rotated = currentImage.rotated90Clockwise() {
            self.images[currentIndex] = rotated
            self.currentNormalizedImage = rotated
            self.imageView.image = rotated
            
            // Rotate the normalized coordinates 90 degrees clockwise:
            // x' = y
            // y' = 1 - x
            let oldTopLeft = self.normTopLeft
            let oldTopRight = self.normTopRight
            let oldBottomLeft = self.normBottomLeft
            let oldBottomRight = self.normBottomRight
            
            self.normTopLeft = CGPoint(x: oldBottomLeft.y, y: 1.0 - oldBottomLeft.x)
            self.normTopRight = CGPoint(x: oldTopLeft.y, y: 1.0 - oldTopLeft.x)
            self.normBottomRight = CGPoint(x: oldTopRight.y, y: 1.0 - oldTopRight.x)
            self.normBottomLeft = CGPoint(x: oldBottomRight.y, y: 1.0 - oldBottomRight.x)
            
            // Save the newly rotated coordinates
            self.savedCoordinates[currentIndex] = PageCoordinates(
                topLeft: self.normTopLeft,
                topRight: self.normTopRight,
                bottomLeft: self.normBottomLeft,
                bottomRight: self.normBottomRight
            )
            
            // Mark points as set up so we don't trigger Vision auto-detection again
            hasSetupPoints = true
            
            // Force redraw of layout and update overlay handle positions
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
    }
    
    /// Navigates back to the previous page in the list.
    @objc private func handleBack() {
        guard currentIndex > 0 else { return }
        
        // Remove the last cropped image
        if !croppedImages.isEmpty {
            croppedImages.removeLast()
        }
        
        currentIndex -= 1
        loadCurrentImage()
    }
    
    /// Applies CIPerspectiveCorrection to un-skew and crop the document area based on specified corner points.
    private func cropImage(image: UIImage, topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) -> UIImage? {
        guard let rawCIImage = CIImage(image: image) else { return nil }
        let ciImage = rawCIImage.oriented(CGImagePropertyOrientation(image.imageOrientation))
        
        let originX = ciImage.extent.origin.x
        let originY = ciImage.extent.origin.y
        let w = ciImage.extent.width
        let h = ciImage.extent.height
        
        let tl = CIVector(x: originX + topLeft.x * w, y: originY + topLeft.y * h)
        let tr = CIVector(x: originX + topRight.x * w, y: originY + topRight.y * h)
        let bl = CIVector(x: originX + bottomLeft.x * w, y: originY + bottomLeft.y * h)
        let br = CIVector(x: originX + bottomRight.x * w, y: originY + bottomRight.y * h)
        
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(tl, forKey: "inputTopLeft")
        filter.setValue(tr, forKey: "inputTopRight")
        filter.setValue(bl, forKey: "inputBottomLeft")
        filter.setValue(br, forKey: "inputBottomRight")
        
        guard let outputImage = filter.outputImage else { return nil }
        
        guard let cgImage = self.ciContext.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
}
