import UIKit

/// A circular zoom lens view that provides pixel-perfect positioning of cropping handles.
/// It renders a magnified segment of the background image centered over the user's touch point.
class MagnifierView: UIView {
    
    /// The cached snapshot image of the parent view controller's main view.
    var snapshotImage: UIImage?
    
    /// The current touch coordinate inside the parent view space to magnify.
    var touchPoint: CGPoint = .zero {
        didSet {
            setNeedsDisplay()
        }
    }
    
    /// Initializes a new magnifier view with a default drop shadow style.
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
    
    /// Renders the magnified circular segment of the snapshot image, a border ring, and a center crosshair.
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
