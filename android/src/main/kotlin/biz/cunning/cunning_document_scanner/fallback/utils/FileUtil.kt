package biz.cunning.cunning_document_scanner.fallback.utils

import android.app.Activity
import android.graphics.BitmapFactory
import android.graphics.pdf.PdfDocument
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
