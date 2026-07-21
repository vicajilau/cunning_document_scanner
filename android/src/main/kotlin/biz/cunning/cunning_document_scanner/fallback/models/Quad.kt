package biz.cunning.cunning_document_scanner.fallback.models

import android.graphics.PointF
import android.graphics.RectF
import biz.cunning.cunning_document_scanner.fallback.enums.QuadCorner
import biz.cunning.cunning_document_scanner.fallback.extensions.distance
import biz.cunning.cunning_document_scanner.fallback.extensions.move
import biz.cunning.cunning_document_scanner.fallback.extensions.multiply
import biz.cunning.cunning_document_scanner.fallback.extensions.toPointF

/// Represents the four corners defining a cropping quadrilateral.
///
/// @param topLeftCorner The top-left corner coordinate.
/// @param topRightCorner The top-right corner coordinate.
/// @param bottomRightCorner The bottom-right corner coordinate.
/// @param bottomLeftCorner The bottom-left corner coordinate.
class Quad(
    val topLeftCorner: PointF,
    val topRightCorner: PointF,
    val bottomRightCorner: PointF,
    val bottomLeftCorner: PointF
) {
    /// Secondary constructor to build a Quad from OpenCV-style Point models.
    constructor(
        topLeftCorner: Point,
        topRightCorner: Point,
        bottomRightCorner: Point,
        bottomLeftCorner: Point
    ) : this(
        topLeftCorner.toPointF(),
        topRightCorner.toPointF(),
        bottomRightCorner.toPointF(),
        bottomLeftCorner.toPointF()
    )

    /// Map associating each QuadCorner enum with its respective coordinate point.
    var corners: MutableMap<QuadCorner, PointF> = mutableMapOf(
        QuadCorner.TOP_LEFT to topLeftCorner,
        QuadCorner.TOP_RIGHT to topRightCorner,
        QuadCorner.BOTTOM_RIGHT to bottomRightCorner,
        QuadCorner.BOTTOM_LEFT to bottomLeftCorner
    )

    /// The four lines forming the boundary edges of the crop zone quadrilateral.
    val edges: Array<Line> get() = arrayOf(
        Line(topLeftCorner, topRightCorner),
        Line(topRightCorner, bottomRightCorner),
        Line(bottomRightCorner, bottomLeftCorner),
        Line(bottomLeftCorner, topLeftCorner)
    )

    /// Returns the QuadCorner closest to the given target coordinate point.
    /// Used to select which handle to drag during touch actions.
    fun getCornerClosestToPoint(point: PointF): QuadCorner {
        return corners.minByOrNull { corner -> corner.value.distance(point) }?.key!!
    }

    /// Displaces the coordinate of the specified corner by a delta offset (dx, dy).
    fun moveCorner(corner: QuadCorner, dx: Float, dy: Float) {
        corners[corner]?.offset(dx, dy)
    }

    /// Maps absolute source photo coordinates to scaling preview widget bounds.
    /// - imagePreviewBounds: Display boundaries of the target preview widget.
    /// - ratio: Image-to-preview scale multiplier factor.
    fun mapOriginalToPreviewImageCoordinates(imagePreviewBounds: RectF, ratio: Float): Quad {
        return Quad(
            topLeftCorner.multiply(ratio).move(
                imagePreviewBounds.left,
                imagePreviewBounds.top
            ),
            topRightCorner.multiply(ratio).move(
                imagePreviewBounds.left,
                imagePreviewBounds.top
            ),
            bottomRightCorner.multiply(ratio).move(
                imagePreviewBounds.left,
                imagePreviewBounds.top
            ),
            bottomLeftCorner.multiply(ratio).move(
                imagePreviewBounds.left,
                imagePreviewBounds.top
            )
        )
    }

    /// Maps preview coordinates back to original absolute pixel bounds.
    /// - imagePreviewBounds: Display boundaries of the preview widget.
    /// - ratio: Image-to-preview scale multiplier factor.
    fun mapPreviewToOriginalImageCoordinates(imagePreviewBounds: RectF, ratio: Float): Quad {
        return Quad(
            topLeftCorner.move(
                -imagePreviewBounds.left,
                -imagePreviewBounds.top
            ).multiply(1 / ratio),
            topRightCorner.move(
                -imagePreviewBounds.left,
                -imagePreviewBounds.top
            ).multiply(1 / ratio),
            bottomRightCorner.move(
                -imagePreviewBounds.left,
                -imagePreviewBounds.top
            ).multiply(1 / ratio),
            bottomLeftCorner.move(
                -imagePreviewBounds.left,
                -imagePreviewBounds.top
            ).multiply(1 / ratio)
        )
    }
}