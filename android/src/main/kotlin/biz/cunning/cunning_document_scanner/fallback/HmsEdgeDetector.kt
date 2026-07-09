package biz.cunning.cunning_document_scanner.fallback

import android.graphics.Bitmap
import biz.cunning.cunning_document_scanner.fallback.models.Point
import biz.cunning.cunning_document_scanner.fallback.models.Quad
import com.huawei.hms.mlsdk.common.MLFrame
import com.huawei.hms.mlsdk.dsc.MLDocumentSkewCorrectionAnalyzerFactory
import com.huawei.hms.mlsdk.dsc.MLDocumentSkewCorrectionAnalyzerSetting

class HmsEdgeDetector : EdgeDetector {
    override fun detect(photo: Bitmap, onComplete: (Quad?) -> Unit) {
        try {
            val setting = MLDocumentSkewCorrectionAnalyzerSetting.Factory().create()
            val analyzer = MLDocumentSkewCorrectionAnalyzerFactory.getInstance()
                .getDocumentSkewCorrectionAnalyzer(setting)
            val frame = MLFrame.fromBitmap(photo)

            analyzer.asyncDocumentSkewDetect(frame)
                .addOnSuccessListener { result: com.huawei.hms.mlsdk.dsc.MLDocumentSkewDetectResult? ->
                    if (result != null) {
                        val lt = result.leftTopPosition
                        val rt = result.rightTopPosition
                        val lb = result.leftBottomPosition
                        val rb = result.rightBottomPosition

                        if (lt != null && rt != null && lb != null && rb != null) {
                            val tl = Point(lt.x.toDouble(), lt.y.toDouble())
                            val tr = Point(rt.x.toDouble(), rt.y.toDouble())
                            val bl = Point(lb.x.toDouble(), lb.y.toDouble())
                            val br = Point(rb.x.toDouble(), rb.y.toDouble())
                            val sortedQuad = sortPoints(listOf(tl, tr, bl, br))
                            analyzer.stop()
                            onComplete(sortedQuad)
                            return@addOnSuccessListener
                        }
                    }
                    analyzer.stop()
                    onComplete(null)
                }
                .addOnFailureListener {
                    try {
                        analyzer.stop()
                    } catch (e: Exception) {}
                    onComplete(null)
                }
        } catch (e: Exception) {
            onComplete(null)
        }
    }

    private fun sortPoints(points: List<Point>): Quad {
        val sortedByY = points.sortedBy { it.y }
        val topPoints = sortedByY.take(2).sortedBy { it.x }
        val bottomPoints = sortedByY.takeLast(2).sortedBy { it.x }

        val topLeft = topPoints[0]
        val topRight = topPoints[1]
        val bottomLeft = bottomPoints[0]
        val bottomRight = bottomPoints[1]

        return Quad(topLeft, topRight, bottomRight, bottomLeft)
    }
}
