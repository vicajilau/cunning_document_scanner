package biz.cunning.cunning_document_scanner.fallback.utils

import android.app.Activity
import android.content.ContentResolver
import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfDocument
import android.net.Uri
import android.os.Environment
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// / Helper utility class to manage local file system resources, temporary files creation, and PDF compiling.
class FileUtil {
    // / Generates a unique temporary image file under the application's pictures directory.
    // / - activity: The current active host Activity.
    // / - pageNumber: The document page number used to prefix the filename.
    @Throws(IOException::class)
    fun createImageFile(
        activity: Activity,
        pageNumber: Int,
    ): File {
        val dateTime: String =
            SimpleDateFormat(
                "yyyyMMdd_HHmmss",
                Locale.US,
            ).format(Date())

        val storageDir: File? = activity.getExternalFilesDir(Environment.DIRECTORY_PICTURES)
        return File.createTempFile(
            "DOCUMENT_SCAN_${pageNumber}_$dateTime",
            ".jpg",
            storageDir,
        )
    }

    // / Generates a unique temporary PDF file target under the application's pictures directory.
    // / - activity: The current active host Activity.
    @Throws(IOException::class)
    fun createPdfFile(activity: Activity): File {
        val dateTime: String =
            SimpleDateFormat(
                "yyyyMMdd_HHmmss",
                Locale.US,
            ).format(Date())

        val storageDir: File? = activity.getExternalFilesDir(Environment.DIRECTORY_PICTURES)
        return File.createTempFile(
            "DOCUMENT_SCAN_$dateTime",
            ".pdf",
            storageDir,
        )
    }

    // / Moves a scanned page image the GMS ML Kit scanner produced into this plugin's own
    // / `DOCUMENT_SCAN_`-prefixed storage, so `cleanCache` can find and remove it.
    // / ML Kit owns and names the source file itself, outside this plugin's naming convention.
    // / - context: Used to read the source URI and resolve the destination directory.
    // / - sourceUri: The page image URI reported by the scanner result.
    // / - pageNumber: The document page number used to prefix the filename.
    @Throws(IOException::class)
    fun movePageToScanStorage(
        context: Context,
        sourceUri: Uri,
        pageNumber: Int,
    ): File {
        val dateTime: String =
            SimpleDateFormat(
                "yyyyMMdd_HHmmss",
                Locale.US,
            ).format(Date())

        val storageDir: File? = context.getExternalFilesDir(Environment.DIRECTORY_PICTURES)
        val destFile =
            File.createTempFile(
                "DOCUMENT_SCAN_${pageNumber}_$dateTime",
                ".jpg",
                storageDir,
            )
        moveUriToFile(context, sourceUri, destFile)
        return destFile
    }

    // / Moves a scanned PDF the GMS ML Kit scanner produced into this plugin's own
    // / `DOCUMENT_SCAN_`-prefixed storage, so `cleanCache` can find and remove it.
    // / - context: Used to read the source URI and resolve the destination directory.
    // / - sourceUri: The PDF URI reported by the scanner result.
    @Throws(IOException::class)
    fun movePdfToScanStorage(
        context: Context,
        sourceUri: Uri,
    ): File {
        val dateTime: String =
            SimpleDateFormat(
                "yyyyMMdd_HHmmss",
                Locale.US,
            ).format(Date())

        val storageDir: File? = context.getExternalFilesDir(Environment.DIRECTORY_PICTURES)
        val destFile =
            File.createTempFile(
                "DOCUMENT_SCAN_$dateTime",
                ".pdf",
                storageDir,
            )
        moveUriToFile(context, sourceUri, destFile)
        return destFile
    }

    // / Moves the content behind a `content://` or `file://` URI into a destination file,
    // / leaving nothing behind at the source.
    // /
    // / Copying alone would strand the scanner's own file: its URI never crosses into Dart,
    // / and `cleanCache` matches only this plugin's `DOCUMENT_SCAN_` prefix, so no caller
    // / could ever reach it. Two copies of a scanned document would sit on disk until the
    // / system reclaimed the cache, which for a confidential scan is exactly the wrong
    // / default.
    // /
    // / A `file://` source is renamed when possible. That avoids writing the document a
    // / second time and leaves no window in which both copies exist. A rename across
    // / storage volumes fails, and a `content://` source cannot be renamed at all, so both
    // / fall back to a stream-and-remove.
    @Throws(IOException::class)
    private fun moveUriToFile(
        context: Context,
        sourceUri: Uri,
        destFile: File,
    ) {
        val sourceFile = asLocalFile(sourceUri)
        if (sourceFile != null && sourceFile.renameTo(destFile)) {
            return
        }

        copyUriToFile(context, sourceUri, destFile)
        deleteSource(context, sourceUri, sourceFile)
    }

    // / Resolves a URI to the file it points at, or null when it does not name one directly.
    // / A missing scheme is treated as a bare filesystem path, which is how `Uri.parse`
    // / represents one.
    private fun asLocalFile(sourceUri: Uri): File? {
        val scheme = sourceUri.scheme
        if (scheme != null && scheme != ContentResolver.SCHEME_FILE) {
            return null
        }
        return sourceUri.path?.let { File(it) }
    }

    // / Removes the scanner's original after its content has been copied out.
    // /
    // / Best-effort by design: the scan itself was read correctly and is already safe in
    // / this plugin's storage, so a source that refuses to be deleted must not turn a
    // / successful scan into a failure. A `content://` provider owned by another process
    // / may reject the delete outright, and the read grant this plugin holds does not
    // / imply a write one.
    private fun deleteSource(
        context: Context,
        sourceUri: Uri,
        sourceFile: File?,
    ) {
        try {
            if (sourceFile != null) {
                sourceFile.delete()
            } else {
                context.contentResolver.delete(sourceUri, null, null)
            }
        } catch (_: RuntimeException) {
            // SecurityException, UnsupportedOperationException and IllegalArgumentException
            // all mean the same thing here: this process is not allowed to remove the
            // source, and there is nothing further to try.
        }
    }

    // / Streams the content behind a `content://` or `file://` URI into a destination file.
    @Throws(IOException::class)
    private fun copyUriToFile(
        context: Context,
        sourceUri: Uri,
        destFile: File,
    ) {
        val input =
            context.contentResolver.openInputStream(sourceUri)
                ?: throw IOException("Unable to open scanner output at $sourceUri")
        input.use { stream ->
            FileOutputStream(destFile).use { output -> stream.copyTo(output) }
        }
    }

    // / Compiles a list of image paths into a single output PDF document.
    // / - imagePaths: List of absolute image paths.
    // / - pdfFile: The output file where the PDF will be written.
    @Throws(IOException::class)
    fun convertImagesToPdf(
        imagePaths: List<String>,
        pdfFile: File,
    ) {
        val pdfDocument = PdfDocument()
        for ((index, imagePath) in imagePaths.withIndex()) {
            val bitmap = BitmapFactory.decodeFile(imagePath) ?: continue
            val pageInfo = PdfDocument.PageInfo.Builder(bitmap.width, bitmap.height, index + 1).create()
            val page = pdfDocument.startPage(pageInfo)
            val canvas = page.canvas
            canvas.drawBitmap(bitmap, 0f, 0f, null)
            pdfDocument.finishPage(page)
            bitmap.recycle()
        }
        FileOutputStream(pdfFile).use { out ->
            pdfDocument.writeTo(out)
        }
        pdfDocument.close()
    }
}
