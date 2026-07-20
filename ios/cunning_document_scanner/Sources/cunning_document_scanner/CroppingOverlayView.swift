import UIKit

/// A overlay canvas overlaying the image view that draws the perspective crop bounding box
/// and exposes four corner handles that the user can drag to define crop coordinates.
class CroppingOverlayView: UIView {
    
    /// The coordinates of the top-left cropping handle in the local coordinate space.
    var topLeft = CGPoint.zero
    
    /// The coordinates of the top-right cropping handle in the local coordinate space.
    var topRight = CGPoint.zero
    
    /// The coordinates of the bottom-left cropping handle in the local coordinate space.
    var bottomLeft = CGPoint.zero
    
    /// The coordinates of the bottom-right cropping handle in the local coordinate space.
    var bottomRight = CGPoint.zero
    
    /// The calculated bounding frame of the aspect-fit image content within the parent UIImageView.
    var contentFrame = CGRect.zero
    
    /// A callback closure invoked whenever any corner handle coordinates are updated by the user.
    var onPointsChanged: (() -> Void)?
    
    /// The views representing the four circular corner touch targets.
    private var handles: [UIView] = []
    
    /// The size/diameter of the corner touch handles.
    private let handleSize: CGFloat = 34
    
    /// The current magnifier lens overlay, visible during active handle dragging.
    private var magnifierView: MagnifierView?
    
    /// The specific handle view currently being dragged by the user, if any.
    /// Used to enforce single-touch drag constraints and prevent multi-touch conflicts.
    private var activeHandle: UIView?
    
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
    
    /// Populates and configures the four corner handle subviews with UIPanGestureRecognizers.
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
    
    /// Updates the visual positions of the corner handles to reflect current coordinate properties.
    func updateHandlePositions() {
        guard handles.count == 4 else { return }
        handles[0].center = topLeft
        handles[1].center = topRight
        handles[2].center = bottomLeft
        handles[3].center = bottomRight
        setNeedsDisplay()
    }
    
    /// Processes UIPanGestureRecognizer drag events to move handles, notify coordinates change,
    /// and present/update the MagnifierView zoom lens.
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let handle = gesture.view else { return }
        
        if let active = activeHandle, active !== handle {
            return
        }
        
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
            activeHandle = handle
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
            activeHandle = nil
        default:
            break
        }
    }
    
    /// Positions and offsets the magnifier view above or below the user's touch coordinate.
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
    
    /// Renders the quad boundary lines and semi-transparent blue filling representing the crop zone.
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
    
    /// Converts a normalized coordinate (0.0 - 1.0, origin bottom-left) to the local view coordinate system.
    func viewPoint(fromNormalized point: CGPoint, contentFrame: CGRect) -> CGPoint {
        guard contentFrame.width > 0 && contentFrame.height > 0 else { return .zero }
        let vx = contentFrame.origin.x + point.x * contentFrame.size.width
        let vy = contentFrame.origin.y + (1.0 - point.y) * contentFrame.size.height
        return CGPoint(x: vx, y: vy)
    }
    
    /// Converts a local view coordinate to a normalized coordinate (0.0 - 1.0, origin bottom-left).
    func normalizedPoint(fromView point: CGPoint, contentFrame: CGRect) -> CGPoint {
        guard contentFrame.width > 0 && contentFrame.height > 0 else { return .zero }
        let px = (point.x - contentFrame.origin.x) / contentFrame.size.width
        let py = 1.0 - (point.y - contentFrame.origin.y) / contentFrame.size.height
        return CGPoint(x: max(0.0, min(1.0, px)), y: max(0.0, min(1.0, py)))
    }
}
