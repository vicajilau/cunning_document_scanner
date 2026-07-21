package biz.cunning.cunning_document_scanner.fallback.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import androidx.appcompat.widget.AppCompatImageButton
import biz.cunning.cunning_document_scanner.R

// / Custom circular image button that draws a white border ring.
// / Used for helper controls like retake and add-new-photo.
class CircleButton(
    context: Context,
    attrs: AttributeSet,
) : AppCompatImageButton(context, attrs) {
    // / The paint configuration for the button's outer ring.
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG)

    init {
        ring.color = Color.WHITE
        ring.style = Paint.Style.STROKE
        ring.strokeWidth = resources.getDimension(R.dimen.small_button_ring_thickness)
    }

    // / Draws the button and renders the custom circular outer ring border.
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        canvas.drawCircle(
            (width / 2).toFloat(),
            (height / 2).toFloat(),
            (width.toFloat() - ring.strokeWidth) / 2,
            ring,
        )
    }
}
