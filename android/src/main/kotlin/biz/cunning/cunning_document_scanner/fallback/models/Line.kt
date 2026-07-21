package biz.cunning.cunning_document_scanner.fallback.models

import android.graphics.PointF

// / Represents a line segment connecting two points.
// /
// / @param fromPoint The starting coordinate.
// / @param toPoint The ending coordinate.
class Line(
    fromPoint: PointF,
    toPoint: PointF,
) {
    // / The starting point of the line segment.
    val from: PointF = fromPoint

    // / The ending point of the line segment.
    val to: PointF = toPoint
}
