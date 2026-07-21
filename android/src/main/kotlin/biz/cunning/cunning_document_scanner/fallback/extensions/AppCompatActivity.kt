package biz.cunning.cunning_document_scanner.fallback.extensions

import android.graphics.Rect
import androidx.appcompat.app.AppCompatActivity

/**
 * @property screenBounds the screen bounds (used to get screen width and height)
 */
@Suppress("DEPRECATION")
val AppCompatActivity.screenBounds: Rect get() {
    // currentWindowMetrics was added in Android R
    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
        return windowManager.currentWindowMetrics.bounds
    }

    // fall back to get screen width and height if using a version before Android R
    return Rect(
        0,
        0,
        windowManager.defaultDisplay.width,
        windowManager.defaultDisplay.height,
    )
}

/**
 * @property screenWidth the screen width
 */
val AppCompatActivity.screenWidth: Int get() = screenBounds.width()

/**
 * @property screenHeight the screen height
 */
val AppCompatActivity.screenHeight: Int get() = screenBounds.height()
