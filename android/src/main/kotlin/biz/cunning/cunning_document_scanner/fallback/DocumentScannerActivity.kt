package biz.cunning.cunning_document_scanner.fallback

import android.app.Activity
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.os.Bundle
import android.view.View
import android.widget.ImageButton
import androidx.appcompat.app.AppCompatActivity
import biz.cunning.cunning_document_scanner.R
import biz.cunning.cunning_document_scanner.fallback.constants.DefaultSetting
import biz.cunning.cunning_document_scanner.fallback.constants.DocumentScannerExtra
import biz.cunning.cunning_document_scanner.fallback.extensions.move
import biz.cunning.cunning_document_scanner.fallback.extensions.onClick
import biz.cunning.cunning_document_scanner.fallback.extensions.saveToFile
import biz.cunning.cunning_document_scanner.fallback.extensions.screenHeight
import biz.cunning.cunning_document_scanner.fallback.extensions.screenWidth
import biz.cunning.cunning_document_scanner.fallback.models.Document
import biz.cunning.cunning_document_scanner.fallback.models.Point
import biz.cunning.cunning_document_scanner.fallback.models.Quad
import biz.cunning.cunning_document_scanner.fallback.ui.ImageCropView
import biz.cunning.cunning_document_scanner.fallback.utils.CameraUtil
import biz.cunning.cunning_document_scanner.fallback.utils.FileUtil
import biz.cunning.cunning_document_scanner.fallback.utils.ImageUtil
import java.io.File

// / This class contains the main document scanner code. It opens the camera, lets the user
// / take a photo of a document (homework paper, business card, etc.), detects document corners,
// / allows user to make adjustments to the detected corners, depending on options, and saves
// / the cropped document. It allows the user to do this for 1 or more documents.
class DocumentScannerActivity : AppCompatActivity() {
    // / Maximum number of documents a user can scan at a time.
    private var maxNumDocuments = DefaultSetting.MAX_NUM_DOCUMENTS

    // / The 0 - 100 quality of the cropped image.
    private var croppedImageQuality = DefaultSetting.CROPPED_IMAGE_QUALITY

    // / Default offset margin used when document corners are not detected.
    private val cropperOffsetWhenCornersNotFound = 100.0

    // / Current document being processed. Set once a photo is taken and corners are resolved.
    private var document: Document? = null

    // / List of scanned/cropped documents containing original paths, dimensions, and corners.
    private val documents = mutableListOf<Document>()

    // / Gallery images still waiting to be cropped, in selection order.
    // / Empty when the activity is driven by the camera instead of by an import.
    private val pendingImageUris = mutableListOf<Uri>()

    // / True when the activity was started to crop images imported from the gallery.
    private var isGalleryImportMode = false

    // / Camera utilities callback delegate to handle camera capture success or cancel events.
    private val cameraUtil =
        CameraUtil(
            this,
            onPhotoCaptureSuccess = { originalPhotoPath ->

                // Hide the add-new-photo button if the documents count reaches max limit minus one
                if (documents.size == maxNumDocuments - 1) {
                    val newPhotoButton: ImageButton = findViewById(R.id.new_photo_button)
                    newPhotoButton.isClickable = false
                    newPhotoButton.visibility = View.INVISIBLE
                }

                val photo: Bitmap? =
                    try {
                        ImageUtil().getImageFromFilePath(originalPhotoPath)
                    } catch (exception: Exception) {
                        finishIntentWithError("Unable to get bitmap: ${exception.localizedMessage}")
                        return@CameraUtil
                    }

                if (photo == null) {
                    finishIntentWithError("Document bitmap is null.")
                    return@CameraUtil
                }

                detectCorners(photo) { corners ->
                    document = Document(originalPhotoPath, photo.width, photo.height, corners)

                    try {
                        imageView.setImagePreviewBounds(photo, screenWidth, screenHeight)
                        imageView.setImage(photo)

                        // Map corners from absolute coordinates to preview bounds coordinates
                        val cornersInImagePreviewCoordinates =
                            corners
                                .mapOriginalToPreviewImageCoordinates(
                                    imageView.imagePreviewBounds,
                                    imageView.imagePreviewBounds.height() / photo.height,
                                )

                        imageView.setCropper(cornersInImagePreviewCoordinates)
                    } catch (exception: Exception) {
                        finishIntentWithError(
                            "unable get image preview ready: ${exception.message}",
                        )
                    }
                }
            },
            onCancelPhoto = {
                if (documents.isEmpty()) {
                    onClickCancel()
                }
            },
        )

    // / Container view holding the preview image and draggable crop overlay.
    private lateinit var imageView: ImageCropView

    // / Called when the activity is first created. Sets up UI buttons, handles intent extras,
    // / and resolves whether to load an initial image URI or launch the camera.
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setContentView(R.layout.activity_image_crop)
        imageView = findViewById(R.id.image_view)

        try {
            var userSpecifiedMaxImages: Int? = null
            intent.extras?.get(DocumentScannerExtra.EXTRA_MAX_NUM_DOCUMENTS)?.let {
                if (it.toString().toIntOrNull() == null) {
                    throw Exception(
                        "${DocumentScannerExtra.EXTRA_MAX_NUM_DOCUMENTS} must be a positive number",
                    )
                }
                userSpecifiedMaxImages = it as Int
                maxNumDocuments = userSpecifiedMaxImages as Int
            }

            intent.extras?.get(DocumentScannerExtra.EXTRA_CROPPED_IMAGE_QUALITY)?.let {
                if (it !is Int || it < 0 || it > 100) {
                    throw Exception(
                        "${DocumentScannerExtra.EXTRA_CROPPED_IMAGE_QUALITY} must be a number " +
                            "between 0 and 100",
                    )
                }
                croppedImageQuality = it
            }
        } catch (exception: Exception) {
            finishIntentWithError(
                "invalid extra: ${exception.message}",
            )
            return
        }

        val newPhotoButton: ImageButton = findViewById(R.id.new_photo_button)
        val completeDocumentScanButton: ImageButton =
            findViewById(
                R.id.complete_document_scan_button,
            )
        val retakePhotoButton: ImageButton = findViewById(R.id.retake_photo_button)

        newPhotoButton.onClick { onClickNew() }
        completeDocumentScanButton.onClick { onClickDone() }
        retakePhotoButton.onClick { onClickRetake() }

        pendingImageUris.addAll(readImageUrisToCrop().take(maxNumDocuments))

        if (pendingImageUris.isNotEmpty()) {
            isGalleryImportMode = true
            // Imported images are cropped one after another; taking or retaking photos
            // makes no sense in this mode.
            newPhotoButton.visibility = View.GONE
            retakePhotoButton.visibility = View.GONE
            loadNextPendingImage()
        } else {
            try {
                openCamera()
            } catch (exception: Exception) {
                finishIntentWithError(
                    "error opening camera: ${exception.message}",
                )
            }
        }
    }

    // / Reads the gallery image URIs to crop from the intent.
    // / Accepts both the multi-image extra and the legacy single-image one.
    private fun readImageUrisToCrop(): List<Uri> {
        val uris = intent.getStringArrayListExtra(DocumentScannerExtra.EXTRA_IMAGE_URIS_TO_CROP)
        if (uris != null && uris.isNotEmpty()) {
            return uris.map { Uri.parse(it) }
        }
        val legacyUri = intent.getStringExtra(DocumentScannerExtra.EXTRA_IMAGE_URI_TO_CROP)
        return legacyUri?.let { listOf(Uri.parse(it)) } ?: emptyList()
    }

    // / Loads the next queued gallery image into the crop view, removing it from the queue.
    private fun loadNextPendingImage() {
        val photoUri = pendingImageUris.removeFirstOrNull() ?: return
        document = null

        try {
            val photo =
                contentResolver.openInputStream(photoUri)?.use { inputStream ->
                    android.graphics.BitmapFactory.decodeStream(inputStream)
                } ?: throw Exception("Failed to decode image from Uri")

            val photoFile = FileUtil().createImageFile(this, documents.size)
            val originalPhotoPath = photoFile.absolutePath
            photo.saveToFile(photoFile, croppedImageQuality)

            detectCorners(photo) { corners ->
                document = Document(originalPhotoPath, photo.width, photo.height, corners)
                try {
                    imageView.setImagePreviewBounds(photo, screenWidth, screenHeight)
                    imageView.setImage(photo)
                    val cornersInImagePreviewCoordinates =
                        corners
                            .mapOriginalToPreviewImageCoordinates(
                                imageView.imagePreviewBounds,
                                imageView.imagePreviewBounds.height() / photo.height,
                            )
                    imageView.setCropper(cornersInImagePreviewCoordinates)
                } catch (exception: Exception) {
                    finishIntentWithError("unable to get image preview ready: ${exception.message}")
                }
            }
        } catch (exception: Exception) {
            finishIntentWithError("error loading image to crop: ${exception.message}")
        }
    }

    // / Resolves document corners asynchronously. Defaults to inset bounding box.
    private fun detectCorners(
        photo: Bitmap,
        onComplete: (Quad) -> Unit,
    ) {
        onComplete(getDefaultCorners(photo))
    }

    // / Computes default fallback corner locations with standard inset offsets.
    private fun getDefaultCorners(photo: Bitmap): Quad =
        Quad(
            Point(0.0, 0.0).move(
                cropperOffsetWhenCornersNotFound,
                cropperOffsetWhenCornersNotFound,
            ),
            Point(photo.width.toDouble(), 0.0).move(
                -cropperOffsetWhenCornersNotFound,
                cropperOffsetWhenCornersNotFound,
            ),
            Point(photo.width.toDouble(), photo.height.toDouble()).move(
                -cropperOffsetWhenCornersNotFound,
                -cropperOffsetWhenCornersNotFound,
            ),
            Point(0.0, photo.height.toDouble()).move(
                cropperOffsetWhenCornersNotFound,
                -cropperOffsetWhenCornersNotFound,
            ),
        )

    // / Resets current document state and launches camera utility intent.
    private fun openCamera() {
        document = null
        cameraUtil.openCamera(documents.size)
    }

    // / Converts preview coordinates to original image coordinates and adds the document to the list.
    private fun addSelectedCornersAndOriginalPhotoPathToDocuments() {
        document?.let { document ->
            val cornersInOriginalImageCoordinates =
                imageView.corners
                    .mapPreviewToOriginalImageCoordinates(
                        imageView.imagePreviewBounds,
                        imageView.imagePreviewBounds.height() / document.originalPhotoHeight,
                    )
            document.corners = cornersInOriginalImageCoordinates
            documents.add(document)
        }
    }

    // / Callback triggered by new photo button click.
    private fun onClickNew() {
        addSelectedCornersAndOriginalPhotoPathToDocuments()
        openCamera()
    }

    // / Callback triggered by complete done button click.
    // / While gallery images remain queued, this advances to the next one instead of finishing.
    private fun onClickDone() {
        addSelectedCornersAndOriginalPhotoPathToDocuments()
        if (isGalleryImportMode && pendingImageUris.isNotEmpty()) {
            loadNextPendingImage()
            return
        }
        cropDocumentAndFinishIntent()
    }

    // / Callback triggered by retake photo button click. Deletes current captured file and opens camera.
    private fun onClickRetake() {
        document?.let { document -> File(document.originalPhotoFilePath).delete() }
        openCamera()
    }

    // / Callback triggered by cancel click. Cancels activity and returns cancel result code.
    private fun onClickCancel() {
        setResult(Activity.RESULT_CANCELED)
        finish()
    }

    // / Crops the documented pages, deletes temporary files, and returns file paths to parent activity.
    private fun cropDocumentAndFinishIntent() {
        val croppedImageResults = arrayListOf<String>()
        for ((pageNumber, document) in documents.withIndex()) {
            val croppedImage: Bitmap? =
                try {
                    ImageUtil().crop(
                        document.originalPhotoFilePath,
                        document.corners,
                    )
                } catch (exception: Exception) {
                    finishIntentWithError("unable to crop image: ${exception.message}")
                    return
                }

            if (croppedImage == null) {
                finishIntentWithError("Result of cropping is null")
                return
            }

            File(document.originalPhotoFilePath).delete()

            try {
                val croppedImageFile = FileUtil().createImageFile(this, pageNumber)
                croppedImage.saveToFile(croppedImageFile, croppedImageQuality)
                val returnedUri = Uri.fromFile(croppedImageFile).toString()
                croppedImageResults.add(returnedUri)
            } catch (exception: Exception) {
                finishIntentWithError(
                    "unable to save cropped image: ${exception.message}",
                )
            }
        }

        setResult(
            Activity.RESULT_OK,
            Intent().putExtra("croppedImageResults", croppedImageResults),
        )
        finish()
    }

    // / Finishes the activity returning an error message in intent extras.
    private fun finishIntentWithError(errorMessage: String) {
        setResult(
            Activity.RESULT_OK,
            Intent().putExtra("error", errorMessage),
        )
        finish()
    }
}
