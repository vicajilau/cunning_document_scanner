package biz.cunning.cunning_document_scanner.fallback.utils

import android.app.Activity
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

    // / Copies a scanned page image the GMS ML Kit scanner produced into this plugin's own
    // / `DOCUMENT_SCAN_`-prefixed storage, so `cleanCache` can find and remove it.
    // / ML Kit owns and names the source file itself, outside this plugin's naming convention.
    // / - context: Used to read the source URI and resolve the destination directory.
    // / - sourceUri: The page image URI reported by the scanner result.
    // / - pageNumber: The document page number used to prefix the filename.
    @Throws(IOException::class)
    fun copyPageToScanStorage(
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
        copyUriToFile(context, sourceUri, destFile)
        return destFile
    }

    // / Copies a scanned PDF the GMS ML Kit scanner produced into this plugin's own
    // / `DOCUMENT_SCAN_`-prefixed storage, so `cleanCache` can find and remove it.
    // / - context: Used to read the source URI and resolve the destination directory.
    // / - sourceUri: The PDF URI reported by the scanner result.
    @Throws(IOException::class)
    fun copyPdfToScanStorage(
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
        copyUriToFile(context, sourceUri, destFile)
        return destFile
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
