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
import android.content.pm.PackageManager
/**
 * This class contains the main document scanner code. It opens the camera, lets the user
 * take a photo of a document (homework paper, business card, etc.), detects document corners,
 * allows user to make adjustments to the detected corners, depending on options, and saves
 * the cropped document. It allows the user to do this for 1 or more documents.
 *
 * @constructor creates document scanner activity
 */
class DocumentScannerActivity : AppCompatActivity() {
    /**
     * @property maxNumDocuments maximum number of documents a user can scan at a time
     */
    private var maxNumDocuments = DefaultSetting.MAX_NUM_DOCUMENTS

    /**
     * @property croppedImageQuality the 0 - 100 quality of the cropped image
     */
    private var croppedImageQuality = DefaultSetting.CROPPED_IMAGE_QUALITY

    /**
     * @property cropperOffsetWhenCornersNotFound if we can't find document corners, we set
     * corners to image size with a slight margin
     */
    private val cropperOffsetWhenCornersNotFound = 100.0

    /**
     * @property document This is the current document. Initially it's null. Once we capture
     * the photo, and find the corners we update document.
     */
    private var document: Document? = null

    /**
     * @property documents a list of documents (original photo file path, original photo
     * dimensions and 4 corner points)
     */
    private val documents = mutableListOf<Document>()

    /**
     * @property cameraUtil gets called with photo file path once user takes photo, or
     * exits camera
     */
    private val cameraUtil = CameraUtil(
        this,
        onPhotoCaptureSuccess = {
            // user takes photo
            originalPhotoPath ->

            // if maxNumDocuments is 3 and this is the 3rd photo, hide the new photo button since
            // we reach the allowed limit
            if (documents.size == maxNumDocuments - 1) {
                val newPhotoButton: ImageButton = findViewById(R.id.new_photo_button)
                newPhotoButton.isClickable = false
                newPhotoButton.visibility = View.INVISIBLE
            }

            // get bitmap from photo file path
            val photo: Bitmap? = try {
                ImageUtil().getImageFromFilePath(originalPhotoPath)
            } catch (exception: Exception) {
                finishIntentWithError("Unable to get bitmap: ${exception.localizedMessage}")
                return@CameraUtil
            }

            if (photo == null) {
                finishIntentWithError("Document bitmap is null.")
                return@CameraUtil
            }

            // get document corners asynchronously using HMS if available, or fallback to default corners
            detectCorners(photo) { corners ->
                document = Document(originalPhotoPath, photo.width, photo.height, corners)

                // user is allowed to move corners to make corrections
                try {
                    // set preview image height based off of photo dimensions
                    imageView.setImagePreviewBounds(photo, screenWidth, screenHeight)

                    // display original photo, so user can adjust detected corners
                    imageView.setImage(photo)

                    // document corner points are in original image coordinates, so we need to
                    // scale and move the points to account for blank space (caused by photo and
                    // photo container having different aspect ratios)
                    val cornersInImagePreviewCoordinates = corners
                        .mapOriginalToPreviewImageCoordinates(
                            imageView.imagePreviewBounds,
                            imageView.imagePreviewBounds.height() / photo.height
                        )

                    // display cropper, and allow user to move corners
                    imageView.setCropper(cornersInImagePreviewCoordinates)
                } catch (exception: Exception) {
                    finishIntentWithError(
                        "unable get image preview ready: ${exception.message}"
                    )
                }
            }
        },
        onCancelPhoto = {
            // user exits camera
            // complete document scan if this is the first document since we can't go to crop view
            // until user takes at least 1 photo
            if (documents.isEmpty()) {
                onClickCancel()
            }
        }
    )

    /**
     * @property imageView container with original photo and cropper
     */
    private lateinit var imageView: ImageCropView

    /**
     * called when activity is created
     *
     * @param savedInstanceState persisted data that maintains state
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Show cropper, accept crop button, add new document button, and
        // retake photo button. Since we open the camera in a few lines, the user
        // doesn't see this until they finish taking a photo
        setContentView(R.layout.activity_image_crop)
        imageView = findViewById(R.id.image_view)

        try {
            // validate maxNumDocuments option, and update default if user sets it
            var userSpecifiedMaxImages: Int? = null
            intent.extras?.get(DocumentScannerExtra.EXTRA_MAX_NUM_DOCUMENTS)?.let {
                if (it.toString().toIntOrNull() == null) {
                    throw Exception(
                        "${DocumentScannerExtra.EXTRA_MAX_NUM_DOCUMENTS} must be a positive number"
                    )
                }
                userSpecifiedMaxImages = it as Int
                maxNumDocuments = userSpecifiedMaxImages as Int
            }

            // validate croppedImageQuality option, and update value if user sets it
            intent.extras?.get(DocumentScannerExtra.EXTRA_CROPPED_IMAGE_QUALITY)?.let {
                if (it !is Int || it < 0 || it > 100) {
                    throw Exception(
                        "${DocumentScannerExtra.EXTRA_CROPPED_IMAGE_QUALITY} must be a number " +
                                "between 0 and 100"
                    )
                }
                croppedImageQuality = it
            }
        } catch (exception: Exception) {
            finishIntentWithError(
                "invalid extra: ${exception.message}"
            )
            return
        }

        // set click event handlers for new document button, accept and crop document button,
        // and retake document photo button
        val newPhotoButton: ImageButton = findViewById(R.id.new_photo_button)
        val completeDocumentScanButton: ImageButton = findViewById(
            R.id.complete_document_scan_button
        )
        val retakePhotoButton: ImageButton = findViewById(R.id.retake_photo_button)

        newPhotoButton.onClick { onClickNew() }
        completeDocumentScanButton.onClick { onClickDone() }
        retakePhotoButton.onClick { onClickRetake() }

        val initialImageUriStr = intent.getStringExtra("EXTRA_IMAGE_URI_TO_CROP")
        android.util.Log.d("DocumentScannerActivity", "onCreate initialImageUriStr: $initialImageUriStr")
        if (initialImageUriStr != null) {
            newPhotoButton.visibility = View.GONE
            retakePhotoButton.visibility = View.GONE
            try {
                val photoUri = Uri.parse(initialImageUriStr)
                android.util.Log.d("DocumentScannerActivity", "Attempting to open Uri stream: $photoUri")
                val photo = contentResolver.openInputStream(photoUri)?.use { inputStream ->
                    android.graphics.BitmapFactory.decodeStream(inputStream)
                } ?: throw Exception("Failed to decode image from Uri")
                android.util.Log.d("DocumentScannerActivity", "Decoded bitmap dimensions: ${photo.width} x ${photo.height}")

                val photoFile = FileUtil().createImageFile(this, 0)
                val originalPhotoPath = photoFile.absolutePath
                photo.saveToFile(photoFile, croppedImageQuality)
                android.util.Log.d("DocumentScannerActivity", "Saved photo to temp file: $originalPhotoPath")

                detectCorners(photo) { corners ->
                    android.util.Log.d("DocumentScannerActivity", "Corners detected: $corners")
                    document = Document(originalPhotoPath, photo.width, photo.height, corners)
                    try {
                        imageView.setImagePreviewBounds(photo, screenWidth, screenHeight)
                        imageView.setImage(photo)
                        val cornersInImagePreviewCoordinates = corners
                            .mapOriginalToPreviewImageCoordinates(
                                imageView.imagePreviewBounds,
                                imageView.imagePreviewBounds.height() / photo.height
                            )
                        imageView.setCropper(cornersInImagePreviewCoordinates)
                        android.util.Log.d("DocumentScannerActivity", "Crop view and cropper initialized")
                    } catch (exception: Exception) {
                        android.util.Log.e("DocumentScannerActivity", "Error setting preview: ${exception.message}")
                        finishIntentWithError("unable to get image preview ready: ${exception.message}")
                    }
                }
            } catch (exception: Exception) {
                android.util.Log.e("DocumentScannerActivity", "Error loading Uri image: ${exception.message}")
                finishIntentWithError("error loading image to crop: ${exception.message}")
            }
        } else {
            // open camera, so user can snap document photo
            try {
                openCamera()
            } catch (exception: Exception) {
                finishIntentWithError(
                    "error opening camera: ${exception.message}"
                )
            }
        }
    }

    private fun isHmsAvailable(): Boolean {
        return try {
            packageManager.getPackageInfo("com.huawei.hwid", 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun isHmsLibraryAvailable(): Boolean {
        return try {
            Class.forName("com.huawei.hms.mlsdk.dsc.MLDocumentSkewCorrectionAnalyzerFactory")
            true
        } catch (e: ClassNotFoundException) {
            false
        }
    }

    private fun detectCorners(photo: Bitmap, onComplete: (Quad) -> Unit) {
        if (isHmsAvailable() && isHmsLibraryAvailable()) {
            try {
                val detectorClass = Class.forName("biz.cunning.cunning_document_scanner.fallback.HmsEdgeDetector")
                val detector = detectorClass.getDeclaredConstructor().newInstance() as EdgeDetector
                detector.detect(photo) { detectedQuad ->
                    if (detectedQuad != null) {
                        onComplete(detectedQuad)
                    } else {
                        onComplete(getDefaultCorners(photo))
                    }
                }
                return
            } catch (e: Exception) {
                android.util.Log.e("DocumentScannerActivity", "Error loading HmsEdgeDetector dynamically", e)
            }
        }
        onComplete(getDefaultCorners(photo))
    }

    private fun getDefaultCorners(photo: Bitmap): Quad {
        return Quad(
            Point(0.0, 0.0).move(
                cropperOffsetWhenCornersNotFound,
                cropperOffsetWhenCornersNotFound
            ),
            Point(photo.width.toDouble(), 0.0).move(
                -cropperOffsetWhenCornersNotFound,
                cropperOffsetWhenCornersNotFound
            ),
            Point(photo.width.toDouble(), photo.height.toDouble()).move(
                -cropperOffsetWhenCornersNotFound,
                -cropperOffsetWhenCornersNotFound
            ),
            Point(0.0, photo.height.toDouble()).move(
                cropperOffsetWhenCornersNotFound,
                -cropperOffsetWhenCornersNotFound
            )
        )
    }

    /**
     * Set document to null since we're capturing a new document, and open the camera. If the
     * user captures a photo successfully document gets updated.
     */
    private fun openCamera() {
        document = null
        cameraUtil.openCamera(documents.size)
    }

    /**
     * Once user accepts by pressing check button, or by pressing add new document button, add
     * original photo path and 4 document corners to documents list. If user isn't allowed to
     * adjust corners, call this automatically.
     */
    private fun addSelectedCornersAndOriginalPhotoPathToDocuments() {
        // only add document it's not null (the current document photo capture, and corner
        // detection are successful)
        document?.let { document ->
            // convert corners from image preview coordinates to original photo coordinates
            // (original image is probably bigger than the preview image)
            val cornersInOriginalImageCoordinates = imageView.corners
                .mapPreviewToOriginalImageCoordinates(
                    imageView.imagePreviewBounds,
                    imageView.imagePreviewBounds.height() / document.originalPhotoHeight
                )
            document.corners = cornersInOriginalImageCoordinates
            documents.add(document)
        }
    }

    /**
     * This gets called when a user presses the new document button. Store current photo path
     * with document corners. Then open the camera, so user can take a photo of the next
     * page or document
     */
    private fun onClickNew() {
        addSelectedCornersAndOriginalPhotoPathToDocuments()
        openCamera()
    }

    /**
     * This gets called when a user presses the done button. Store current photo path with
     * document corners. Then crop document using corners, and return cropped image paths
     */
    private fun onClickDone() {
        addSelectedCornersAndOriginalPhotoPathToDocuments()
        cropDocumentAndFinishIntent()
    }

    /**
     * This gets called when a user presses the retake photo button. The user presses this in
     * case the original document photo isn't good, and they need to take it again.
     */
    private fun onClickRetake() {
        // we're going to retake the photo, so delete the one we just took
        document?.let { document -> File(document.originalPhotoFilePath).delete() }
        openCamera()
    }

    /**
     * This gets called when a user doesn't want to complete the document scan after starting.
     * For example a user can quit out of the camera before snapping a photo of the document.
     */
    private fun onClickCancel() {
        setResult(Activity.RESULT_CANCELED)
        finish()
    }

    /**
     * This crops original document photo, saves cropped document photo, deletes original
     * document photo, and returns cropped document photo file path. It repeats that for
     * all document photos.
     */
    private fun cropDocumentAndFinishIntent() {
        val croppedImageResults = arrayListOf<String>()
        android.util.Log.d("DocumentScannerActivity", "cropDocumentAndFinishIntent starting for ${documents.size} documents")
        for ((pageNumber, document) in documents.withIndex()) {
            // crop document photo by using corners
            val croppedImage: Bitmap? = try {
                ImageUtil().crop(
                    document.originalPhotoFilePath,
                    document.corners
                )
            } catch (exception: Exception) {
                android.util.Log.e("DocumentScannerActivity", "Error cropping page $pageNumber: ${exception.message}")
                finishIntentWithError("unable to crop image: ${exception.message}")
                return
            }

            if (croppedImage == null) {
                android.util.Log.e("DocumentScannerActivity", "Cropped image is null for page $pageNumber")
                finishIntentWithError("Result of cropping is null")
                return
            }

            // delete original document photo
            File(document.originalPhotoFilePath).delete()

            // save cropped document photo
            try {
                val croppedImageFile = FileUtil().createImageFile(this, pageNumber)
                croppedImage.saveToFile(croppedImageFile, croppedImageQuality)
                val returnedUri = Uri.fromFile(croppedImageFile).toString()
                android.util.Log.d("DocumentScannerActivity", "Saved cropped image page $pageNumber to: $returnedUri")
                croppedImageResults.add(returnedUri)
            } catch (exception: Exception) {
                android.util.Log.e("DocumentScannerActivity", "Error saving cropped image page $pageNumber: ${exception.message}")
                finishIntentWithError(
                    "unable to save cropped image: ${exception.message}"
                )
            }
        }

        // return array of cropped document photo file paths
        android.util.Log.d("DocumentScannerActivity", "Finishing success with cropped results: $croppedImageResults")
        setResult(
            Activity.RESULT_OK,
            Intent().putExtra("croppedImageResults", croppedImageResults)
        )
        finish()
    }

    /**
     * This ends the document scanner activity, and returns an error message that can be
     * used to debug error
     *
     * @param errorMessage an error message
     */
    private fun finishIntentWithError(errorMessage: String) {
        setResult(
            Activity.RESULT_OK,
            Intent().putExtra("error", errorMessage)
        )
        finish()
    }
}