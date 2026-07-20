import UIKit
import Vision
import CoreImage

protocol CunningDocumentCropperDelegate: AnyObject {
    func didFinishCropping(croppedImages: [UIImage])
    func didCancelCropping()
}

class CunningDocumentCropperViewController: UIViewController {
    weak var delegate: CunningDocumentCropperDelegate?
    
    private var images: [UIImage] = []
    private var croppedImages: [UIImage] = []
    private var currentIndex = 0
    
    private let imageView = UIImageView()
    private let overlayView = CroppingOverlayView()
    private let topBar = UIView()
    private let bottomBar = UIView()
    
    private let titleLabel = UILabel()
    private let cancelButton = UIButton(type: .system)
    private let doneButton = UIButton(type: .system)
    private let rotateButton = UIButton(type: .system)
    private let backButton = UIButton(type: .system)
    
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let ciContext = CIContext(options: nil)
    
    private struct PageCoordinates {
        let topLeft: CGPoint
        let topRight: CGPoint
        let bottomLeft: CGPoint
        let bottomRight: CGPoint
    }
    
    private var savedCoordinates: [PageCoordinates?] = []
    
    private var hasSetupPoints = false
    private var hasUserModifiedPoints = false
    private var currentNormalizedImage: UIImage?
    private let localize: (String, String) -> String
    
    // Normalized coordinates (origin at bottom-left)
    private var normTopLeft = CGPoint(x: 0.15, y: 0.85)
    private var normTopRight = CGPoint(x: 0.85, y: 0.85)
    private var normBottomLeft = CGPoint(x: 0.15, y: 0.15)
    private var normBottomRight = CGPoint(x: 0.85, y: 0.15)
    
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
    
    private func updateHandlesToMatchNormalizedPoints() {
        let frame = getContentFrame()
        overlayView.topLeft = overlayView.viewPoint(fromNormalized: normTopLeft, contentFrame: frame)
        overlayView.topRight = overlayView.viewPoint(fromNormalized: normTopRight, contentFrame: frame)
        overlayView.bottomLeft = overlayView.viewPoint(fromNormalized: normBottomLeft, contentFrame: frame)
        overlayView.bottomRight = overlayView.viewPoint(fromNormalized: normBottomRight, contentFrame: frame)
        overlayView.updateHandlePositions()
    }
    
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
            
            DispatchQueue.main.async {
                self.cancelButton.isEnabled = true
                self.doneButton.isEnabled = true
                self.rotateButton.isEnabled = true
                self.backButton.isEnabled = true
                self.activityIndicator.stopAnimating()
                
                if let cropped = cropped {
                    self.croppedImages.append(cropped)
                } else {
                    // Fallback to original image if cropping failed
                    self.croppedImages.append(currentImage)
                }
                
                self.currentIndex += 1
                if self.currentIndex < self.images.count {
                    self.loadCurrentImage()
                } else {
                    self.delegate?.didFinishCropping(croppedImages: self.croppedImages)
                }
            }
        }
    }
    
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
    
    @objc private func handleBack() {
        guard currentIndex > 0 else { return }
        
        // Remove the last cropped image
        if !croppedImages.isEmpty {
            croppedImages.removeLast()
        }
        
        currentIndex -= 1
        loadCurrentImage()
    }
    
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

// MARK: - CroppingOverlayView

class CroppingOverlayView: UIView {
    var topLeft = CGPoint.zero
    var topRight = CGPoint.zero
    var bottomLeft = CGPoint.zero
    var bottomRight = CGPoint.zero
    
    var contentFrame = CGRect.zero
    var onPointsChanged: (() -> Void)?
    
    private var handles: [UIView] = []
    private let handleSize: CGFloat = 34
    private var magnifierView: MagnifierView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        setupHandles()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        setupHandles()
    }
    
    private func setupHandles() {
        for i in 0..<4 {
            let handle = UIView(frame: CGRect(x: 0, y: 0, width: handleSize, height: handleSize))
            handle.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
            handle.layer.cornerRadius = handleSize / 2
            handle.layer.borderWidth = 3
            handle.layer.borderColor = UIColor.white.cgColor
            handle.tag = i
            
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            handle.addGestureRecognizer(pan)
            addSubview(handle)
            handles.append(handle)
        }
    }
    
    func updateHandlePositions() {
        guard handles.count == 4 else { return }
        handles[0].center = topLeft
        handles[1].center = topRight
        handles[2].center = bottomLeft
        handles[3].center = bottomRight
        setNeedsDisplay()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let handle = gesture.view else { return }
        let translation = gesture.translation(in: self)
        var newCenter = CGPoint(x: handle.center.x + translation.x, y: handle.center.y + translation.y)
        
        // Restrict drag inside the image content frame (if set)
        if contentFrame != .zero {
            newCenter.x = max(contentFrame.minX, min(contentFrame.maxX, newCenter.x))
            newCenter.y = max(contentFrame.minY, min(contentFrame.maxY, newCenter.y))
        } else {
            newCenter.x = max(0, min(bounds.width, newCenter.x))
            newCenter.y = max(0, min(bounds.height, newCenter.y))
        }
        
        handle.center = newCenter
        gesture.setTranslation(.zero, in: self)
        
        switch handle.tag {
        case 0: topLeft = newCenter
        case 1: topRight = newCenter
        case 2: bottomLeft = newCenter
        case 3: bottomRight = newCenter
        default: break
        }
        
        onPointsChanged?()
        setNeedsDisplay()
        
        // Magnifier View updates
        let touchPointInSelf = newCenter
        guard let parentView = self.superview else { return }
        let touchPointInParent = self.convert(touchPointInSelf, to: parentView)
        
        switch gesture.state {
        case .began:
            let magnifier = MagnifierView(frame: CGRect(x: 0, y: 0, width: 90, height: 90))
            
            // Temporarily hide the overlay view so it isn't captured in the zoom lens background
            self.isHidden = true
            
            // Snapshot the parent view once
            let renderer = UIGraphicsImageRenderer(size: parentView.bounds.size)
            let snapshot = renderer.image { ctx in
                parentView.layer.render(in: ctx.cgContext)
            }
            
            // Restore visibility
            self.isHidden = false
            
            magnifier.snapshotImage = snapshot
            parentView.addSubview(magnifier)
            self.magnifierView = magnifier
            updateMagnifier(touchPoint: touchPointInParent, touchPointInSelf: touchPointInParent)
        case .changed:
            updateMagnifier(touchPoint: touchPointInParent, touchPointInSelf: touchPointInParent)
        case .ended, .cancelled:
            magnifierView?.removeFromSuperview()
            magnifierView = nil
        default:
            break
        }
    }
    
    private func updateMagnifier(touchPoint: CGPoint, touchPointInSelf: CGPoint) {
        guard let magnifier = magnifierView, let parentView = self.superview else { return }
        magnifier.touchPoint = touchPointInSelf
        
        let halfHeight = magnifier.bounds.height / 2
        
        // Position the magnifier offset above the touch point.
        // If the touch point is too close to the top, position it below the touch point to avoid going off-screen or being covered by the finger.
        let isNearTop = (touchPoint.y - 75) < halfHeight
        let yOffset: CGFloat = isNearTop ? 75 : -75
        var magnifierCenter = CGPoint(x: touchPoint.x, y: touchPoint.y + yOffset)
        
        // Keep the magnifier within the parent view bounds
        let halfWidth = magnifier.bounds.width / 2
        
        magnifierCenter.x = max(halfWidth, min(parentView.bounds.width - halfWidth, magnifierCenter.x))
        magnifierCenter.y = max(halfHeight, min(parentView.bounds.height - halfHeight, magnifierCenter.y))
        
        magnifier.center = magnifierCenter
    }
    
    override func draw(_ rect: CGRect) {
        guard topLeft != .zero || topRight != .zero || bottomLeft != .zero || bottomRight != .zero else {
            return
        }
        
        let path = UIBezierPath()
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.close()
        
        // Draw fill area
        UIColor.systemBlue.withAlphaComponent(0.25).setFill()
        path.fill()
        
        // Draw crop frame lines
        UIColor.systemBlue.setStroke()
        path.lineWidth = 3
        path.stroke()
    }
    
    // Convert points coordinate mappings
    func viewPoint(fromNormalized point: CGPoint, contentFrame: CGRect) -> CGPoint {
        guard contentFrame.width > 0 && contentFrame.height > 0 else { return .zero }
        let vx = contentFrame.origin.x + point.x * contentFrame.size.width
        let vy = contentFrame.origin.y + (1.0 - point.y) * contentFrame.size.height
        return CGPoint(x: vx, y: vy)
    }
    
    func normalizedPoint(fromView point: CGPoint, contentFrame: CGRect) -> CGPoint {
        guard contentFrame.width > 0 && contentFrame.height > 0 else { return .zero }
        let px = (point.x - contentFrame.origin.x) / contentFrame.size.width
        let py = 1.0 - (point.y - contentFrame.origin.y) / contentFrame.size.height
        return CGPoint(x: max(0.0, min(1.0, px)), y: max(0.0, min(1.0, py)))
    }
}

// MARK: - UIImage Extension (Fix Orientation)

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = self.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    func rotated90Clockwise() -> UIImage? {
        let newOrientation: UIImage.Orientation
        switch self.imageOrientation {
        case .up: newOrientation = .right
        case .right: newOrientation = .down
        case .down: newOrientation = .left
        case .left: newOrientation = .up
        case .upMirrored: newOrientation = .rightMirrored
        case .rightMirrored: newOrientation = .downMirrored
        case .downMirrored: newOrientation = .leftMirrored
        case .leftMirrored: newOrientation = .upMirrored
        @unknown default: newOrientation = .right
        }
        
        if let cgImage = self.cgImage {
            return UIImage(cgImage: cgImage, scale: self.scale, orientation: newOrientation)
        } else if let ciImage = self.ciImage {
            return UIImage(ciImage: ciImage, scale: self.scale, orientation: newOrientation)
        }
        return nil
    }
    
    func downscaled(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let size = self.size
        let maxDim = max(size.width, size.height)
        if maxDim <= maxDimension {
            return self
        }
        
        let scale = maxDimension / maxDim
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0 // Use 1.0 scale to keep exact pixel dimensions
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - MagnifierView

class MagnifierView: UIView {
    var snapshotImage: UIImage?
    var touchPoint: CGPoint = .zero {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 4
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let image = snapshotImage else { return }
        
        // Circular clipping
        let path = UIBezierPath(ovalIn: rect)
        path.addClip()
        
        context.translateBy(x: rect.width / 2, y: rect.height / 2)
        context.scaleBy(x: 1.5, y: 1.5)
        context.translateBy(x: -touchPoint.x, y: -touchPoint.y)
        
        image.draw(at: .zero)
        
        // Draw border ring
        UIColor.white.setStroke()
        let borderPath = UIBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5))
        borderPath.lineWidth = 3
        borderPath.stroke()
        
        // Draw crosshair in the center
        UIColor.systemBlue.setStroke()
        let crosshair = UIBezierPath()
        let midX = rect.midX
        let midY = rect.midY
        crosshair.move(to: CGPoint(x: midX - 8, y: midY))
        crosshair.addLine(to: CGPoint(x: midX + 8, y: midY))
        crosshair.move(to: CGPoint(x: midX, y: midY - 8))
        crosshair.addLine(to: CGPoint(x: midX, y: midY + 8))
        crosshair.lineWidth = 1.5
        crosshair.stroke()
    }
}

// MARK: - CGImagePropertyOrientation Mapping Helper

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        case .left: self = .left
        @unknown default: self = .up
        }
    }
}
