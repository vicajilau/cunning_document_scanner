package biz.cunning.cunning_document_scanner.fallback

import android.graphics.Bitmap
import biz.cunning.cunning_document_scanner.fallback.models.Quad

interface EdgeDetector {
    fun detect(
        photo: Bitmap,
        onComplete: (Quad?) -> Unit,
    )
}
