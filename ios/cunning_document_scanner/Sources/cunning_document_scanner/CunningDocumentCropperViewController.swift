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
    
    private var hasSetupPoints = false
    private let localize: (String, String) -> String
    
    // Normalized coordinates (origin at bottom-left)
    private var normTopLeft = CGPoint(x: 0.15, y: 0.85)
    private var normTopRight = CGPoint(x: 0.85, y: 0.85)
    private var normBottomLeft = CGPoint(x: 0.15, y: 0.15)
    private var normBottomRight = CGPoint(x: 0.85, y: 0.15)
    
    init(images: [UIImage], localize: @escaping (String, String) -> String) {
        self.localize = localize
        super.init(nibName: nil, bundle: nil)
        // Normalize orientations of all images first
        self.images = images.map { $0.fixedOrientation() }
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
            let frame = self.getContentFrame()
            self.normTopLeft = self.overlayView.normalizedPoint(fromView: self.overlayView.topLeft, contentFrame: frame)
            self.normTopRight = self.overlayView.normalizedPoint(fromView: self.overlayView.topRight, contentFrame: frame)
            self.normBottomLeft = self.overlayView.normalizedPoint(fromView: self.overlayView.bottomLeft, contentFrame: frame)
            self.normBottomRight = self.overlayView.normalizedPoint(fromView: self.overlayView.bottomRight, contentFrame: frame)
        }
        view.addSubview(overlayView)
        
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
        
        cancelButton.setTitle(localize("cunning_document_scanner_cancel", "Cancel"), for: .normal)
        cancelButton.setTitleColor(.systemRed, for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        cancelButton.addTarget(self, action: #selector(handleCancel), for: .touchUpInside)
        bottomBar.addSubview(cancelButton)
        
        doneButton.setTitle(localize("cunning_document_scanner_next", "Next"), for: .normal)
        doneButton.setTitleColor(.systemBlue, for: .normal)
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        doneButton.addTarget(self, action: #selector(handleDone), for: .touchUpInside)
        bottomBar.addSubview(doneButton)
        
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
        
        NSLayoutConstraint.activate([
            // Top Bar
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 50),
            
            titleLabel.centerXAnchor.constraint(equalTo: topBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            
            // Bottom Bar
            bottomBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 60),
            
            cancelButton.leadingAnchor.constraint(equalTo: bottomBar.leadingAnchor, constant: 20),
            cancelButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            
            doneButton.trailingAnchor.constraint(equalTo: bottomBar.trailingAnchor, constant: -20),
            doneButton.centerYAnchor.constraint(equalTo: bottomBar.centerYAnchor),
            
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
        
        let currentImage = images[currentIndex]
        imageView.image = currentImage
        
        // Update Title and Done Button Label
        let pageNum = currentIndex + 1
        let titleFormat = localize("cunning_document_scanner_crop_title", "Crop Page %d of %d")
        titleLabel.text = String(format: titleFormat, pageNum, images.count)
        
        let doneTitle = (currentIndex == images.count - 1)
            ? localize("cunning_document_scanner_done", "Done")
            : localize("cunning_document_scanner_next", "Next")
        doneButton.setTitle(doneTitle, for: .normal)
        
        // Reset flags for the new image detection
        hasSetupPoints = false
        view.setNeedsLayout()
    }
    
    private func detectAndSetupPoints() {
        guard currentIndex < images.count else { return }
        let currentImage = images[currentIndex]
        
        // Set default points initially
        self.normTopLeft = CGPoint(x: 0.15, y: 0.85)
        self.normTopRight = CGPoint(x: 0.85, y: 0.85)
        self.normBottomLeft = CGPoint(x: 0.15, y: 0.15)
        self.normBottomRight = CGPoint(x: 0.85, y: 0.15)
        
        self.updateHandlesToMatchNormalizedPoints()
        
        // Run vision detection asynchronously
        guard let cgImage = currentImage.cgImage else { return }
        let request = VNDetectDocumentSegmentationRequest { [weak self] request, error in
            guard let self = self else { return }
            guard error == nil,
                  let results = request.results as? [VNRectangleObservation],
                  let firstResult = results.first else {
                return // Use defaults
            }
            
            DispatchQueue.main.async {
                // Verify we are still on the same image
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
        delegate?.didCancelCropping()
    }
    
    @objc private func handleDone() {
        guard currentIndex < images.count else { return }
        
        // Show spinner / block buttons to prevent double-tap
        cancelButton.isEnabled = false
        doneButton.isEnabled = false
        
        let currentImage = images[currentIndex]
        
        // Crop the current image on a background thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let cropped = self.cropImage(
                image: currentImage,
                topLeft: self.normTopLeft,
                topRight: self.normTopRight,
                bottomLeft: self.normBottomLeft,
                bottomRight: self.normBottomRight
            )
            
            DispatchQueue.main.async {
                self.cancelButton.isEnabled = true
                self.doneButton.isEnabled = true
                
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
    
    private func cropImage(image: UIImage, topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let w = image.size.width
        let h = image.size.height
        
        let tl = CIVector(x: topLeft.x * w, y: topLeft.y * h)
        let tr = CIVector(x: topRight.x * w, y: topRight.y * h)
        let bl = CIVector(x: bottomLeft.x * w, y: bottomLeft.y * h)
        let br = CIVector(x: bottomRight.x * w, y: bottomRight.y * h)
        
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(tl, forKey: "inputTopLeft")
        filter.setValue(tr, forKey: "inputTopRight")
        filter.setValue(bl, forKey: "inputBottomLeft")
        filter.setValue(br, forKey: "inputBottomRight")
        
        guard let outputImage = filter.outputImage else { return nil }
        
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        
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
            let handle = UIView()
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
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
}
