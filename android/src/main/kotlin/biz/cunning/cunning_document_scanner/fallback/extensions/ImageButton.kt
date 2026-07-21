package biz.cunning.cunning_document_scanner.fallback.extensions

import android.widget.ImageButton

/**
 * This function adds an on click listener to the button. It makes the button not clickable,
 * calls the on click function, and then makes the button clickable. This prevents the on click
 * function from being called while it runs.
 *
 * @param onClick the click event handler
 */
fun ImageButton.onClick(onClick: () -> Unit) {
    setOnClickListener {
        isClickable = false
        onClick()
        isClickable = true
    }
}
