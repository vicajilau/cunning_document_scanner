package biz.cunning.cunning_document_scanner.fallback.extensions

import android.graphics.Bitmap
import java.io.File
import java.io.FileOutputStream
import kotlin.math.sqrt

/**
 * This converts the bitmap to base64
 *
 * @param file the bitmap gets saved to this file
 */
fun Bitmap.saveToFile(
    file: File,
    quality: Int,
) {
    val fileOutputStream = FileOutputStream(file)
    compress(Bitmap.CompressFormat.JPEG, quality, fileOutputStream)
    fileOutputStream.close()
}

/**
 * This resizes the image, so that the byte count is a little less than targetBytes
 *
 * @param targetBytes the returned bitmap has a size a little less than targetBytes
 */
fun Bitmap.changeByteCountByResizing(targetBytes: Int): Bitmap {
    val scale = sqrt(targetBytes.toDouble() / byteCount.toDouble())
    return Bitmap.createScaledBitmap(
        this,
        (width * scale).toInt(),
        (height * scale).toInt(),
        true,
    )
}
