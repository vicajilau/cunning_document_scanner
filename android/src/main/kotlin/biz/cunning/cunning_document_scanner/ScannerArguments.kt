package biz.cunning.cunning_document_scanner

import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.SCANNER_MODE_BASE
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.SCANNER_MODE_BASE_WITH_FILTER
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.SCANNER_MODE_FULL

// / Pure helpers translating method channel arguments and file names.
// / Kept free of Android framework types so they can be unit tested on the JVM.
object ScannerArguments {
    // / Prefix applied by the plugin to every file it writes.
    // / Only files carrying it are considered plugin output and are safe to delete.
    const val SCAN_FILE_PREFIX = "DOCUMENT_SCAN_"

    // / Maps the `androidScannerMode` method channel value to its ML Kit constant.
    // / Unknown or missing values fall back to the full pipeline.
    fun resolveScannerMode(mode: String?): Int =
        when (mode) {
            "base" -> SCANNER_MODE_BASE
            "base_with_filter" -> SCANNER_MODE_BASE_WITH_FILTER
            else -> SCANNER_MODE_FULL
        }

    // / Resolves the effective scanner source, honouring the deprecated
    // / `isGalleryImportAllowed` flag only when `scannerSource` was not supplied.
    fun resolveScannerSource(
        scannerSource: String?,
        isGalleryImportAllowed: Boolean?,
    ): String =
        scannerSource
            ?: if (isGalleryImportAllowed == true) "camera_and_gallery" else "camera"

    // / Whether a file name belongs to this plugin and may be removed by `cleanCache`.
    // /
    // / Matching on the prefix alone is deliberate: the plugin shares `cacheDir` and the
    // / pictures directory with the host application, and matching on extension would
    // / delete the host application's own images and PDFs.
    fun isPluginScanFile(fileName: String): Boolean = fileName.startsWith(SCAN_FILE_PREFIX)
}
