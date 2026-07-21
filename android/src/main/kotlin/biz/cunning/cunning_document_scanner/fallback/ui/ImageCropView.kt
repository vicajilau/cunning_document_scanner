package biz.cunning.cunning_document_scanner.fallback.ui

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PointF
import android.graphics.RectF
import android.graphics.Shader
import android.util.AttributeSet
import android.view.MotionEvent
import androidx.appcompat.widget.AppCompatImageView
import androidx.core.graphics.drawable.toBitmap
import biz.cunning.cunning_document_scanner.R
import biz.cunning.cunning_document_scanner.fallback.enums.QuadCorner
import biz.cunning.cunning_document_scanner.fallback.extensions.changeByteCountByResizing
import biz.cunning.cunning_document_scanner.fallback.extensions.drawQuad
import biz.cunning.cunning_document_scanner.fallback.models.Quad

// / Custom ImageView displaying the original document photo and an interactive cropping box.
// / Enables users to drag crop corners to correct skewing manually.
class ImageCropView(
    context: Context,
    attrs: AttributeSet,
) : AppCompatImageView(context, attrs) {
    // / The quadrilateral object representing the four corners of the cropping window.
    private var quad: Quad? = null

    // / Tracks the previous touch point coordinate to calculate displacement distances.
    private var prevTouchPoint: PointF? = null

    // / Identifies the corner nearest to the user's touch action being actively dragged.
    private var closestCornerToTouch: QuadCorner? = null

    // / Styling paint configuration for the cropping overlay borders and lines.
    private val cropperLinesAndCornersStyles = Paint(Paint.ANTI_ALIAS_FLAG)

    // / Shader fill configurations used to draw a magnified lens over the active corner during drags.
    private val cropperSelectedCornerFillStyles = Paint()

    // / Internal cached height of the image preview container.
    private var imagePreviewHeight = height

    // / Internal cached width of the image preview container.
    private var imagePreviewWidth = width

    // / Ratio representing the height ratio of the preview widget relative to the intrinsic drawable height.
    private val ratio: Float get() = imagePreviewBounds.height() / drawable.intrinsicHeight

    // / Public getter returning current corner points in preview coordinate terms.
    val corners: Quad get() = quad!!

    // / Maximum memory size limit in bytes before scaling down high-resolution image previews.
    private val imagePreviewMaxSizeInBytes = 100 * 1024 * 1024

    init {
        cropperLinesAndCornersStyles.color = Color.WHITE
        cropperLinesAndCornersStyles.style = Paint.Style.STROKE
        cropperLinesAndCornersStyles.strokeWidth = 3f
    }

    // / Computes and updates layout bounds for the image preview window to maintain original aspect ratio.
    // / - photo: The target original bitmap to render.
    // / - screenWidth: Host device screen width parameter.
    // / - screenHeight: Host device screen height parameter.
    fun setImagePreviewBounds(
        photo: Bitmap,
        screenWidth: Int,
        screenHeight: Int,
    ) {
        val imageRatio = photo.width.toFloat() / photo.height.toFloat()
        val buttonsViewMinHeight =
            context.resources
                .getDimension(
                    R.dimen.buttons_container_min_height,
                ).toInt()

        imagePreviewHeight =
            if (photo.height > photo.width) {
                (screenWidth.toFloat() / imageRatio).toInt()
            } else {
                (screenWidth.toFloat() * imageRatio).toInt()
            }

        imagePreviewHeight =
            Integer.min(
                imagePreviewHeight,
                screenHeight - buttonsViewMinHeight,
            )

        imagePreviewWidth = screenWidth

        layoutParams.height = imagePreviewHeight
        layoutParams.width = imagePreviewWidth

        requestLayout()
    }

    // / Downscales the source image if needed to save RAM, sets it as the drawable, and updates the shader canvas.
    fun setImage(photo: Bitmap) {
        var previewImagePhoto = photo
        if (photo.byteCount > imagePreviewMaxSizeInBytes) {
            previewImagePhoto = photo.changeByteCountByResizing(imagePreviewMaxSizeInBytes)
        }
        this.setImageBitmap(previewImagePhoto)
        this.onSetImage()
    }

    // / Sets the current cropping corner points within this view.
    fun setCropper(cropperCorners: Quad) {
        quad = cropperCorners
    }

    // / RectF boundaries defining the actual rendered image inside the Aspect-Fit crop container.
    val imagePreviewBounds: RectF
        get() {
            val imageViewRatio: Float = imagePreviewWidth.toFloat() / imagePreviewHeight.toFloat()
            val imageRatio = drawable.intrinsicWidth.toFloat() / drawable.intrinsicHeight.toFloat()

            var left = 0f
            var top = 0f
            var right = imagePreviewWidth.toFloat()
            var bottom = imagePreviewHeight.toFloat()

            if (imageRatio > imageViewRatio) {
                val offset = (imagePreviewHeight - (imagePreviewWidth / imageRatio)) / 2
                top += offset
                bottom -= offset
            } else {
                val offset = (imagePreviewWidth - (imagePreviewHeight * imageRatio)) / 2
                left += offset
                right -= offset
            }

            return RectF(left, top, right, bottom)
        }

    // / Verifies if a given coordinate point lies inside the valid visible preview image boundaries.
    private fun isPointInsideImage(point: PointF): Boolean {
        if (point.x >= imagePreviewBounds.left &&
            point.y >= imagePreviewBounds.top &&
            point.x <= imagePreviewBounds.right &&
            point.y <= imagePreviewBounds.bottom
        ) {
            return true
        }

        return false
    }

    // / Initializes a BitmapShader with the active preview drawable content to run magnifier zooms.
    private fun onSetImage() {
        cropperSelectedCornerFillStyles.style = Paint.Style.FILL
        cropperSelectedCornerFillStyles.shader =
            BitmapShader(
                drawable.toBitmap(),
                Shader.TileMode.CLAMP,
                Shader.TileMode.CLAMP,
            )
    }

    // / Redraws the crop quad polygon, corner circles, and the magnifying glass overlay.
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        if (quad !== null) {
            canvas.drawQuad(
                quad!!,
                resources.getDimension(R.dimen.cropper_corner_radius),
                cropperLinesAndCornersStyles,
                cropperSelectedCornerFillStyles,
                closestCornerToTouch,
                imagePreviewBounds,
                ratio,
                resources.getDimension(R.dimen.cropper_selected_corner_radius_magnification),
                resources.getDimension(R.dimen.cropper_selected_corner_background_magnification),
            )
        }
    }

    // / Processes MotionEvents to locate, drag, and release corner handles.
    @SuppressLint("ClickableViewAccessibility")
    override fun onTouchEvent(event: MotionEvent): Boolean {
        val touchPoint = PointF(event.x, event.y)

        when (event.action) {
            MotionEvent.ACTION_DOWN -> {
                prevTouchPoint = touchPoint
                closestCornerToTouch = quad!!.getCornerClosestToPoint(touchPoint)
            }

            MotionEvent.ACTION_UP -> {
                prevTouchPoint = null
                closestCornerToTouch = null
            }

            MotionEvent.ACTION_MOVE -> {
                val touchMoveXDistance = touchPoint.x - prevTouchPoint!!.x
                val touchMoveYDistance = touchPoint.y - prevTouchPoint!!.y
                val cornerNewPosition =
                    PointF(
                        quad!!.corners[closestCornerToTouch]!!.x + touchMoveXDistance,
                        quad!!.corners[closestCornerToTouch]!!.y + touchMoveYDistance,
                    )

                if (isPointInsideImage(cornerNewPosition)) {
                    quad!!.moveCorner(closestCornerToTouch!!, touchMoveXDistance, touchMoveYDistance)
                }

                prevTouchPoint = touchPoint
            }
        }

        invalidate()
        return true
    }
}
