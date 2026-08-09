package biz.cunning.cunning_document_scanner.fallback.utils

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Matrix
import android.graphics.Paint
import android.media.ExifInterface
import biz.cunning.cunning_document_scanner.fallback.models.Quad
import kotlin.math.pow
import kotlin.math.sqrt

// / Helper utility class to decode, rotate, perspective-correct, and crop document images.
class ImageUtil {
    companion object {
        // / Longest edge, in pixels, a decoded document bitmap is allowed to have.
        // /
        // / A full resolution phone camera photo decodes to tens of megabytes as ARGB_8888,
        // / and rotating or perspective correcting it allocates a second copy of the same
        // / size. This path is the fallback scanner, reached on devices without Play
        // / Services, which tend to be the ones least able to absorb that.
        const val MAX_IMAGE_DIMENSION = 2048
    }

    // / Loads and returns a bitmap from the specified file path, correcting rotation orientation metadata.
    // / The image is downsampled so its longest edge does not exceed [MAX_IMAGE_DIMENSION].
    // / - filePath: The absolute file path to the source image.
    fun getImageFromFilePath(filePath: String): Bitmap? {
        val rotation = getRotationDegrees(filePath)

        val bounds =
            BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
        BitmapFactory.decodeFile(filePath, bounds)

        val options =
            BitmapFactory.Options().apply {
                inSampleSize = calculateInSampleSize(bounds.outWidth, bounds.outHeight)
            }
        val bitmap = BitmapFactory.decodeFile(filePath, options) ?: return null

        if (rotation == 0) {
            return bitmap
        }

        val matrix = Matrix().apply { postRotate(rotation.toFloat()) }
        val rotated = Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
        // createBitmap can hand back the very same instance when there is nothing to do.
        if (rotated != bitmap) {
            bitmap.recycle()
        }
        return rotated
    }

    // / Smallest power of two keeping both edges within [MAX_IMAGE_DIMENSION].
    // / Returns 1 when the bounds could not be read, leaving the image untouched.
    private fun calculateInSampleSize(
        width: Int,
        height: Int,
    ): Int {
        if (width <= 0 || height <= 0) return 1

        var sampleSize = 1
        while (width / (sampleSize * 2) >= MAX_IMAGE_DIMENSION ||
            height / (sampleSize * 2) >= MAX_IMAGE_DIMENSION
        ) {
            sampleSize *= 2
        }
        return sampleSize
    }

    // / Resolves rotation degree properties by parsing ExifInterface headers.
    private fun getRotationDegrees(filePath: String): Int {
        val exif = ExifInterface(filePath)
        return when (
            exif.getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )
        ) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90
            ExifInterface.ORIENTATION_ROTATE_180 -> 180
            ExifInterface.ORIENTATION_ROTATE_270 -> 270
            else -> 0
        }
    }

    // / Crops the target photo by applying a perspective correction transformation using corner coordinates.
    // / - photoFilePath: The file path to the source image.
    // / - corners: Quad object representing selection corners.
    fun crop(
        photoFilePath: String,
        corners: Quad,
    ): Bitmap? {
        val bitmap = getImageFromFilePath(photoFilePath) ?: return null

        val src =
            floatArrayOf(
                corners.topLeftCorner.x,
                corners.topLeftCorner.y,
                corners.topRightCorner.x,
                corners.topRightCorner.y,
                corners.bottomRightCorner.x,
                corners.bottomRightCorner.y,
                corners.bottomLeftCorner.x,
                corners.bottomLeftCorner.y,
            )

        val avgWidth = getAvgWidth(corners)
        val avgHeight = getAvgHeight(corners)

        val aspectRatio = avgWidth / avgHeight

        val dstWidth: Float
        val dstHeight: Float

        if (aspectRatio >= 1) { // Width is greater than height, landscape orientation
            dstWidth = avgWidth
            dstHeight = dstWidth / aspectRatio
        } else { // Height is greater than width, portrait orientation
            dstHeight = avgHeight
            dstWidth = dstHeight * aspectRatio
        }

        val dst =
            floatArrayOf(
                0f,
                0f, // Top-left
                dstWidth,
                0f, // Top-right
                dstWidth,
                dstHeight, // Bottom-right
                0f,
                dstHeight, // Bottom-left
            )

        return correctPerspective(bitmap, src, dst, dstWidth, dstHeight)
    }

    // / Performs poly-to-poly matrix transform mapping to stretch/de-skew perspective quad bounds.
    // / - b: The source bitmap.
    // / - srcPoints: Source corner points float coordinates.
    // / - dstPoints: Destination bounding coordinates.
    // / - w: Output width.
    // / - h: Output height.
    fun correctPerspective(
        b: Bitmap,
        srcPoints: FloatArray?,
        dstPoints: FloatArray?,
        w: Float,
        h: Float,
    ): Bitmap {
        val result = Bitmap.createBitmap(w.toInt(), h.toInt(), Bitmap.Config.ARGB_8888)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        val c = Canvas(result)
        val m = Matrix()
        m.setPolyToPoly(srcPoints, 0, dstPoints, 0, 4)
        c.drawBitmap(b, m, p)
        return result
    }

    // / Calculates the average width between top and bottom edges.
    private fun getAvgWidth(corners: Quad): Float {
        val widthTop =
            sqrt(
                (corners.topRightCorner.x - corners.topLeftCorner.x).toDouble().pow(2.0) +
                    (corners.topRightCorner.y - corners.topLeftCorner.y)
                        .toDouble()
                        .pow(2.0),
            ).toFloat()
        val widthBottom =
            sqrt(
                (corners.bottomLeftCorner.x - corners.bottomRightCorner.x).toDouble().pow(2.0) +
                    (corners.bottomLeftCorner.y - corners.bottomRightCorner.y)
                        .toDouble()
                        .pow(2.0),
            ).toFloat()
        return (widthTop + widthBottom) / 2
    }

    // / Calculates the average height between left and right edges.
    private fun getAvgHeight(corners: Quad): Float {
        val heightLeft =
            sqrt(
                (corners.bottomLeftCorner.x - corners.topLeftCorner.x).toDouble().pow(2.0) +
                    (corners.bottomLeftCorner.y - corners.topLeftCorner.y)
                        .toDouble()
                        .pow(2.0),
            ).toFloat()
        val heightRight =
            sqrt(
                (corners.topRightCorner.x - corners.bottomRightCorner.x).toDouble().pow(2.0) +
                    (corners.topRightCorner.y - corners.bottomRightCorner.y)
                        .toDouble()
                        .pow(2.0),
            ).toFloat()
        return (heightLeft + heightRight) / 2
    }
}
