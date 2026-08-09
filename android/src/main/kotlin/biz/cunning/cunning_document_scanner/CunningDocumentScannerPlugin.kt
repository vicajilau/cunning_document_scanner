package biz.cunning.cunning_document_scanner

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.IntentSender
import android.net.Uri
import androidx.core.app.ActivityCompat
import biz.cunning.cunning_document_scanner.fallback.DocumentScannerActivity
import biz.cunning.cunning_document_scanner.fallback.constants.DocumentScannerExtra
import biz.cunning.cunning_document_scanner.fallback.utils.FileUtil
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.RESULT_FORMAT_JPEG
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.RESULT_FORMAT_PDF
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import java.io.File

// / Main Android plugin class for cunning_document_scanner.
// / Handles Flutter MethodChannel calls, Google Play Services (GMS) document scanner triggers,
// / photo picking from gallery, and fallback cropping flows.
class CunningDocumentScannerPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware {
    // / Delegate to handle activity result callbacks.
    private var delegate: PluginRegistry.ActivityResultListener? = null

    // / Binding associated with the current activity.
    private var binding: ActivityPluginBinding? = null

    // / The pending Flutter Result object to return scanned images paths back.
    // / Held for the duration of a single `getPictures` flow and cleared by `resolve`/`fail`.
    private var pendingResult: Result? = null

    // / Flag to check if scanned document must be exported as PDF.
    private var asPdf: Boolean = false

    // / Maximum number of pages requested for the in-flight scan.
    private var noOfPages: Int = DEFAULT_NO_OF_PAGES

    // / The current Android activity instance, or null while detached.
    private var activity: Activity? = null

    // / The MethodChannel that handles communication between Flutter and native Android.
    private lateinit var channel: MethodChannel

    private companion object {
        // / Request code constants for starting activities.
        const val START_DOCUMENT_ACTIVITY: Int = 0x362738
        const val START_DOCUMENT_FB_ACTIVITY: Int = 0x362737
        const val START_GALLERY_PICKER: Int = 0x362736

        // / Page limit applied when the Dart side does not supply one.
        const val DEFAULT_NO_OF_PAGES: Int = 100
    }

    // / Called when the plugin is attached to the Flutter Engine.
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "cunning_document_scanner")
        channel.setMethodCallHandler(this)
    }

    // / Handles MethodChannel method calls from Dart/Flutter.
    override fun onMethodCall(
        call: MethodCall,
        result: Result,
    ) {
        when (call.method) {
            "cleanCache" -> cleanCache(result)
            "getPictures" -> startGetPictures(call, result)
            else -> result.notImplemented()
        }
    }

    // / Validates plugin state and dispatches a scan to the requested source.
    private fun startGetPictures(
        call: MethodCall,
        result: Result,
    ) {
        // A single result callback is held at a time. Starting a second scan would orphan
        // the first one, leaving its Dart Future pending forever.
        if (pendingResult != null) {
            result.error("ALREADY_ACTIVE", "A document scan is already in progress", null)
            return
        }

        if (activity == null) {
            result.error("NO_ACTIVITY", "Plugin is not attached to an Activity", null)
            return
        }

        this.noOfPages = call.argument<Int>("noOfPages") ?: DEFAULT_NO_OF_PAGES
        this.asPdf = call.argument<Boolean>("asPdf") ?: false
        this.pendingResult = result

        val scannerSource =
            ScannerArguments.resolveScannerSource(
                call.argument<String>("scannerSource"),
                call.argument<Boolean>("isGalleryImportAllowed"),
            )
        val scannerMode = ScannerArguments.resolveScannerMode(call.argument<String>("androidScannerMode"))

        if (scannerSource == "gallery") {
            startGalleryPicker()
        } else {
            startScan(noOfPages, scannerSource == "camera_and_gallery", scannerMode, asPdf)
        }
    }

    // / Completes the pending Flutter call with a value and releases it.
    private fun resolve(value: Any?) {
        pendingResult?.success(value)
        pendingResult = null
    }

    // / Completes the pending Flutter call with an error and releases it.
    private fun fail(
        code: String,
        message: String,
    ) {
        pendingResult?.error(code, message, null)
        pendingResult = null
    }

    // / Clears the files this plugin created, and only those.
    // /
    // / Matching is done on the `DOCUMENT_SCAN_` prefix rather than on the file extension:
    // / `cacheDir` and the pictures directory are shared with the host application, and
    // / deleting every image or PDF found there would destroy the host application's data.
    private fun cleanCache(result: Result) {
        val currentActivity = activity
        if (currentActivity == null) {
            result.error("NO_ACTIVITY", "Plugin is not attached to an Activity", null)
            return
        }

        try {
            val picturesDir = currentActivity.getExternalFilesDir(android.os.Environment.DIRECTORY_PICTURES)
            listOfNotNull(picturesDir, currentActivity.cacheDir).forEach { dir ->
                dir.listFiles()?.forEach { file ->
                    if (ScannerArguments.isPluginScanFile(file.name)) {
                        file.delete()
                    }
                }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("CLEAN_CACHE_ERROR", e.localizedMessage, null)
        }
    }

    // / Called when the plugin is detached from the Flutter Engine.
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    // / Called when the plugin is attached to the host Activity.
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.activity = binding.activity
        addActivityResultListener(binding)
    }

    // / Starts the Android system gallery image picker intent.
    private fun startGalleryPicker() {
        val intent =
            Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "image/*"
                putExtra(Intent.EXTRA_ALLOW_MULTIPLE, noOfPages > 1)
            }

        try {
            activity?.startActivityForResult(intent, START_GALLERY_PICKER)
        } catch (_: ActivityNotFoundException) {
            fail("ERROR", "Failed to start gallery picker")
        }
    }

    // / Extracts every image URI the picker returned.
    // /
    // / A multi-selection arrives in `clipData` with `data` left null, so reading `data`
    // / alone silently loses every selection but a single one.
    private fun extractSelectedImageUris(data: Intent?): List<Uri> {
        if (data == null) return emptyList()

        data.clipData?.let { clip ->
            return (0 until clip.itemCount).mapNotNull { clip.getItemAt(it).uri }
        }
        return listOfNotNull(data.data)
    }

    // / Launches the fallback cropper over the images picked from the gallery.
    private fun startCropperForGalleryImages(uris: List<Uri>) {
        val currentActivity = activity
        if (currentActivity == null) {
            fail("NO_ACTIVITY", "Plugin is not attached to an Activity")
            return
        }

        val limitedUris = uris.take(noOfPages)
        val intent =
            Intent(currentActivity, DocumentScannerActivity::class.java).apply {
                // The cropper runs in the host application's process but still needs read
                // access to the provider-backed URIs the picker handed us.
                data = limitedUris.first()
                clipData =
                    ClipData.newRawUri("", limitedUris.first()).also { clip ->
                        limitedUris.drop(1).forEach { clip.addItem(ClipData.Item(it)) }
                    }
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                putStringArrayListExtra(
                    DocumentScannerExtra.EXTRA_IMAGE_URIS_TO_CROP,
                    ArrayList(limitedUris.map { it.toString() }),
                )
                putExtra(DocumentScannerExtra.EXTRA_MAX_NUM_DOCUMENTS, limitedUris.size)
            }

        try {
            ActivityCompat.startActivityForResult(currentActivity, intent, START_DOCUMENT_FB_ACTIVITY, null)
        } catch (e: ActivityNotFoundException) {
            fail("ERROR", "Failed to start cropper activity: ${e.message}")
        }
    }

    // / Handles the result of the system gallery picker.
    private fun handleGalleryPickerResult(
        resultCode: Int,
        data: Intent?,
    ) {
        when (resultCode) {
            Activity.RESULT_OK -> {
                val uris = extractSelectedImageUris(data)
                if (uris.isEmpty()) {
                    fail("ERROR", "No image selected")
                } else {
                    startCropperForGalleryImages(uris)
                }
            }

            else -> resolve(null)
        }
    }

    // / Handles the result of the GMS ML Kit document scanner.
    private fun handleGmsScannerResult(
        resultCode: Int,
        data: Intent?,
    ) {
        if (resultCode != Activity.RESULT_OK) {
            resolve(null)
            return
        }

        val error = data?.extras?.getString("error")
        if (error != null) {
            fail("ERROR", "error - $error")
            return
        }

        val scanningResult =
            data?.extras?.let { extras ->
                androidx.core.os.BundleCompat.getParcelable(
                    extras,
                    "extra_scanning_result",
                    GmsDocumentScanningResult::class.java,
                )
            }

        if (scanningResult == null) {
            fail("ERROR", "No scanning result returned from ML Kit scanner")
            return
        }

        if (asPdf) {
            val pdfUri =
                scanningResult.pdf
                    ?.uri
                    ?.toString()
                    ?.removePrefix("file://")
            if (pdfUri != null) {
                resolve(listOf(pdfUri))
            } else {
                fail("ERROR", "No PDF returned from ML Kit scanner")
            }
        } else {
            val successResponse =
                scanningResult.pages
                    ?.map { it.imageUri.toString().removePrefix("file://") }
                    .orEmpty()
            resolve(successResponse)
        }
    }

    // / Handles the result of the fallback cropper activity.
    private fun handleFallbackScannerResult(
        resultCode: Int,
        data: Intent?,
    ) {
        if (resultCode != Activity.RESULT_OK) {
            resolve(null)
            return
        }

        val error = data?.extras?.getString("error")
        if (error != null) {
            fail("ERROR", "error - $error")
            return
        }

        val croppedImageResults = data?.getStringArrayListExtra("croppedImageResults")
        if (croppedImageResults == null) {
            fail("ERROR", "No cropped images returned")
            return
        }

        val successResponse = croppedImageResults.map { it.removePrefix("file://") }

        if (asPdf) {
            val currentActivity = activity
            if (currentActivity == null) {
                fail("NO_ACTIVITY", "Plugin is not attached to an Activity")
                return
            }
            try {
                val pdfFile = FileUtil().createPdfFile(currentActivity)
                FileUtil().convertImagesToPdf(successResponse, pdfFile)
                successResponse.forEach { File(it).delete() }
                resolve(listOf(pdfFile.absolutePath))
            } catch (e: Exception) {
                fail("ERROR", "Failed to create PDF from fallback scanner: ${e.message}")
            }
        } else {
            resolve(successResponse)
        }
    }

    // / Registers the ActivityResultListener to handle image selection and scanning result intents.
    private fun addActivityResultListener(binding: ActivityPluginBinding) {
        this.binding = binding
        if (this.delegate == null) {
            this.delegate =
                PluginRegistry.ActivityResultListener { requestCode, resultCode, data ->
                    when (requestCode) {
                        START_GALLERY_PICKER -> handleGalleryPickerResult(resultCode, data)
                        START_DOCUMENT_ACTIVITY -> handleGmsScannerResult(resultCode, data)
                        START_DOCUMENT_FB_ACTIVITY -> handleFallbackScannerResult(resultCode, data)
                        else -> return@ActivityResultListener false
                    }
                    return@ActivityResultListener true
                }
        } else {
            binding.removeActivityResultListener(this.delegate!!)
        }

        binding.addActivityResultListener(delegate!!)
    }

    // / Creates an Intent to launch the fallback document scanner activity.
    private fun createDocumentScanIntent(noOfPages: Int): Intent {
        val documentScanIntent = Intent(activity, DocumentScannerActivity::class.java)

        documentScanIntent.putExtra(
            DocumentScannerExtra.EXTRA_MAX_NUM_DOCUMENTS,
            noOfPages,
        )

        return documentScanIntent
    }

    // / Configures GmsDocumentScannerOptions and launches GMS Document Scanner activity.
    private fun startScan(
        noOfPages: Int,
        isGalleryImportAllowed: Boolean,
        scannerMode: Int,
        asPdf: Boolean,
    ) {
        val currentActivity = activity
        if (currentActivity == null) {
            fail("NO_ACTIVITY", "Plugin is not attached to an Activity")
            return
        }

        val optionsBuilder =
            GmsDocumentScannerOptions
                .Builder()
                .setGalleryImportAllowed(isGalleryImportAllowed)
                .setPageLimit(noOfPages)
                .setScannerMode(scannerMode)

        if (asPdf) {
            optionsBuilder.setResultFormats(RESULT_FORMAT_PDF)
        } else {
            optionsBuilder.setResultFormats(RESULT_FORMAT_JPEG)
        }

        val options = optionsBuilder.build()
        try {
            val scanner = GmsDocumentScanning.getClient(options)
            scanner
                .getStartScanIntent(currentActivity)
                .addOnSuccessListener {
                    try {
                        currentActivity.startIntentSenderForResult(it, START_DOCUMENT_ACTIVITY, null, 0, 0, 0)
                    } catch (_: IntentSender.SendIntentException) {
                        fail("ERROR", "Failed to start document scanner")
                    }
                }.addOnFailureListener {
                    openFallbackScanner(noOfPages)
                }
        } catch (_: Exception) {
            openFallbackScanner(noOfPages)
        }
    }

    // / Opens the fallback manual cropping scanner activity if GMS is unavailable.
    private fun openFallbackScanner(noOfPages: Int) {
        val currentActivity = activity
        if (currentActivity == null) {
            fail("NO_ACTIVITY", "Plugin is not attached to an Activity")
            return
        }

        val intent = createDocumentScanIntent(noOfPages)
        try {
            ActivityCompat.startActivityForResult(
                currentActivity,
                intent,
                START_DOCUMENT_FB_ACTIVITY,
                null,
            )
        } catch (_: ActivityNotFoundException) {
            fail("ERROR", "Failed to start document scanner activity")
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        this.activity = binding.activity
        addActivityResultListener(binding)
    }

    override fun onDetachedFromActivity() {
        removeActivityResultListener()
        this.activity = null
    }

    // / Removes ActivityResultListener callback registrations.
    private fun removeActivityResultListener() {
        this.delegate?.let { this.binding?.removeActivityResultListener(it) }
    }
}
