package biz.cunning.cunning_document_scanner.fallback.ui

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.util.AttributeSet
import androidx.appcompat.widget.AppCompatImageButton
import androidx.core.content.ContextCompat
import biz.cunning.cunning_document_scanner.R
import biz.cunning.cunning_document_scanner.fallback.extensions.drawCheck

// / Custom Done checkmark button with custom inner circle fill and outer ring border.
class DoneButton(
    context: Context,
    attrs: AttributeSet,
) : AppCompatImageButton(context, attrs) {
    // / The paint configuration for the button's outer ring.
    private val ring = Paint(Paint.ANTI_ALIAS_FLAG)

    // / The paint configuration for the button's inner circle.
    private val circle = Paint(Paint.ANTI_ALIAS_FLAG)

    init {
        ring.color = Color.WHITE
        ring.style = Paint.Style.STROKE
        ring.strokeWidth = resources.getDimension(R.dimen.large_button_ring_thickness)

        circle.color = ContextCompat.getColor(context, R.color.done_button_inner_circle_color)
        circle.style = Paint.Style.FILL
    }

    // / Renders the done button elements including outer ring, inner circle, and the checkmark icon.
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)

        val centerX = width.toFloat() / 2
        val centerY = height.toFloat() / 2
        val outerRadius = (width.toFloat() - ring.strokeWidth) / 2
        val innerRadius =
            outerRadius -
                resources.getDimension(
                    R.dimen.large_button_outer_ring_offset,
                )

        canvas.drawCircle(centerX, centerY, outerRadius, ring)
        canvas.drawCircle(centerX, centerY, innerRadius, circle)
        canvas.drawCheck(centerX, centerY, drawable)
    }
}
