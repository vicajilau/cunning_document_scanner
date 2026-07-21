import UIKit
import ImageIO

// MARK: - UIImage Extension (Fix Orientation, Rotation, Downscaling)

extension UIImage {
    
    /// Returns a new UIImage with upright (.up) orientation.
    /// It forces the redraw of pixels into a graphics context if the image orientation is not already upright.
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up { return self }
        
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = self.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    
    /// Returns a new UIImage rotated 90 degrees clockwise by changing its orientation metadata.
    /// This is an instant metadata operation that does not copy or modify raw pixel buffers.
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
    
    /// Downscales the image so its maximum dimension (width or height) does not exceed the specified limit.
    /// Keeps exact pixel dimensions using 1.0 scale and outputs a normalized (.up) orientation image.
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

// MARK: - CGImagePropertyOrientation Mapping Helper

extension CGImagePropertyOrientation {
    
    /// Maps a `UIImage.Orientation` enum value to its corresponding `CGImagePropertyOrientation` counterpart.
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
