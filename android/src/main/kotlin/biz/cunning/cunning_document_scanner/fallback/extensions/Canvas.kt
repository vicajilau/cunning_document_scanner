package biz.cunning.cunning_document_scanner.fallback.extensions

import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.PointF
import android.graphics.RectF
import android.graphics.drawable.Drawable
import biz.cunning.cunning_document_scanner.fallback.enums.QuadCorner
import biz.cunning.cunning_document_scanner.fallback.models.Line
import biz.cunning.cunning_document_scanner.fallback.models.Quad

/**
 * This draws a quad (used to draw cropper). It draws 4 circles and
 * 4 connecting lines
 *
 * @param quad 4 corners
 * @param pointRadius corner circle radius
 * @param cropperLinesAndCornersStyles quad style (color, thickness for example)
 * @param cropperSelectedCornerFillStyles style for selected corner
 * @param selectedCorner selected corner
 */
fun Canvas.drawQuad(
    quad: Quad,
    pointRadius: Float,
    cropperLinesAndCornersStyles: Paint,
    cropperSelectedCornerFillStyles: Paint,
    selectedCorner: QuadCorner?,
    imagePreviewBounds: RectF,
    ratio: Float,
    selectedCornerRadiusMagnification: Float,
    selectedCornerBackgroundMagnification: Float,
) {
    // draw 4 corner points
    for ((quadCorner: QuadCorner, cornerPoint: PointF) in quad.corners) {
        var circleRadius = pointRadius

        if (quadCorner === selectedCorner) {
            // the cropper corner circle grows when you touch and drag it
            circleRadius = selectedCornerRadiusMagnification * pointRadius
            val matrix = Matrix()
            matrix.postScale(ratio, ratio, ratio / cornerPoint.x, ratio / cornerPoint.y)
            matrix.postTranslate(imagePreviewBounds.left, imagePreviewBounds.top)
            matrix.postScale(
                selectedCornerBackgroundMagnification,
                selectedCornerBackgroundMagnification,
                cornerPoint.x,
                cornerPoint.y,
            )
            cropperSelectedCornerFillStyles.shader.setLocalMatrix(matrix)
            // fill selected corner circle with magnified image, so it's easier to crop
            drawCircle(cornerPoint.x, cornerPoint.y, circleRadius, cropperSelectedCornerFillStyles)
        }

        // draw corner circles
        drawCircle(
            cornerPoint.x,
            cornerPoint.y,
            circleRadius,
            cropperLinesAndCornersStyles,
        )
    }

    // draw 4 connecting lines
    for (edge: Line in quad.edges) {
        drawLine(edge.from.x, edge.from.y, edge.to.x, edge.to.y, cropperLinesAndCornersStyles)
    }
}

/**
 * This draws the check icon on the finish document scan button. It's needed
 * because the inner circle covers the check icon.
 *
 * @param buttonCenterX the button center x coordinate
 * @param buttonCenterY the button center y coordinate
 * @param drawable the check icon
 */
fun Canvas.drawCheck(
    buttonCenterX: Float,
    buttonCenterY: Float,
    drawable: Drawable,
) {
    val mutate = drawable.constantState?.newDrawable()?.mutate()
    mutate?.setBounds(
        (buttonCenterX - drawable.intrinsicWidth.toFloat() / 2).toInt(),
        (buttonCenterY - drawable.intrinsicHeight.toFloat() / 2).toInt(),
        (buttonCenterX + drawable.intrinsicWidth.toFloat() / 2).toInt(),
        (buttonCenterY + drawable.intrinsicHeight.toFloat() / 2).toInt(),
    )
    mutate?.draw(this)
}
