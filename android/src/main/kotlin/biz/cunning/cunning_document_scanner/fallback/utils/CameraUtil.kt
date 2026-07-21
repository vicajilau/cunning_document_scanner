package biz.cunning.cunning_document_scanner.fallback.utils

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import androidx.activity.ComponentActivity
import androidx.activity.result.ActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import java.io.File
import java.io.IOException

// / Helper utility class to launch the device's system camera, handle photo capture output files,
// / and notify completion/cancel event callbacks.
// /
// / @param activity The host ComponentActivity context.
// / @param onPhotoCaptureSuccess Callback triggered with absolute image path on successful capture.
// / @param onCancelPhoto Callback triggered when the user aborts/cancels image capture.
class CameraUtil(
    private val activity: ComponentActivity,
    private val onPhotoCaptureSuccess: (photoFilePath: String) -> Unit,
    private val onCancelPhoto: () -> Unit,
) {
    // / Holds the file path target for the captured photo.
    private lateinit var photoFilePath: String

    // / ActivityResultLauncher callback handling camera capture intent results.
    private val startForResult =
        activity.registerForActivityResult(
            ActivityResultContracts.StartActivityForResult(),
        ) { result: ActivityResult ->
            when (result.resultCode) {
                Activity.RESULT_OK -> {
                    onPhotoCaptureSuccess(photoFilePath)
                }

                Activity.RESULT_CANCELED -> {
                    File(photoFilePath).delete()
                    onCancelPhoto()
                }
            }
        }

    // / Launches an image capture intent and maps output to a temporary image file.
    // / - pageNumber: The current page index of the document.
    @Throws(IOException::class)
    fun openCamera(pageNumber: Int) {
        val takePictureIntent = Intent(MediaStore.ACTION_IMAGE_CAPTURE)

        val photoFile: File = FileUtil().createImageFile(activity, pageNumber)

        photoFilePath = photoFile.absolutePath

        val photoURI: Uri =
            FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.DocumentScannerFileProvider",
                photoFile,
            )
        takePictureIntent.putExtra(MediaStore.EXTRA_OUTPUT, photoURI)

        startForResult.launch(takePictureIntent)
    }
}
