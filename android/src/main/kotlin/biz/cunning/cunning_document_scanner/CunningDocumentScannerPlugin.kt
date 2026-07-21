package biz.cunning.cunning_document_scanner

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import android.content.IntentSender
import androidx.core.app.ActivityCompat
import biz.cunning.cunning_document_scanner.fallback.DocumentScannerActivity
import biz.cunning.cunning_document_scanner.fallback.constants.DocumentScannerExtra
import biz.cunning.cunning_document_scanner.fallback.utils.FileUtil
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.RESULT_FORMAT_JPEG
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.RESULT_FORMAT_PDF
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.SCANNER_MODE_BASE
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.SCANNER_MODE_BASE_WITH_FILTER
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.SCANNER_MODE_FULL
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

/// Main Android plugin class for cunning_document_scanner.
/// Handles Flutter MethodChannel calls, Google Play Services (GMS) document scanner triggers,
/// photo picking from gallery, and fallback cropping flows.
class CunningDocumentScannerPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
    
    /// Delegate to handle activity result callbacks.
    private var delegate: PluginRegistry.ActivityResultListener? = null
    
    /// Binding associated with the current activity.
    private var binding: ActivityPluginBinding? = null
    
    /// The pending Flutter Result object to return scanned images paths back.
    private var pendingResult: Result? = null
    
    /// Flag to check if scanned document must be exported as PDF.
    private var asPdf: Boolean = false
    
    /// The current Android activity instance.
    private lateinit var activity: Activity
    
    /// Request code constants for starting activities.
    private val START_DOCUMENT_ACTIVITY: Int = 0x362738
    private val START_DOCUMENT_FB_ACTIVITY: Int = 0x362737
    private val START_GALLERY_PICKER: Int = 0x362736

    /// The MethodChannel that handles communication between Flutter and native Android.
    private lateinit var channel: MethodChannel

    /// Called when the plugin is attached to the Flutter Engine.
    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "cunning_document_scanner")
        channel.setMethodCallHandler(this)
    }

    /// Handles MethodChannel method calls from Dart/Flutter.
    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method == "cleanCache") {
            cleanCache(result)
            return
        }

        if (call.method == "getPictures") {
            val noOfPages = call.argument<Int>("noOfPages") ?: 50
            val scannerSource = call.argument<String>("scannerSource") ?: if (call.argument<Boolean>("isGalleryImportAllowed") == true) "camera_and_gallery" else "camera"
            android.util.Log.d("CunningScannerPlugin", "onMethodCall - scannerSource received: $scannerSource")
            val scannerMode = resolveScannerMode(call.argument<String>("androidScannerMode"))
            this.asPdf = call.argument<Boolean>("asPdf") ?: false
            this.pendingResult = result
            
            if (scannerSource == "gallery") {
                android.util.Log.d("CunningScannerPlugin", "Calling startGalleryPicker()")
                startGalleryPicker()
            } else {
                val isGalleryImportAllowed = (scannerSource == "camera_and_gallery")
                android.util.Log.d("CunningScannerPlugin", "Calling startScan with isGalleryImportAllowed=$isGalleryImportAllowed")
                startScan(noOfPages, isGalleryImportAllowed, scannerMode, asPdf)
            }
        } else {
            result.notImplemented()
        }
    }

    /// Clears temporary scan files (.jpg, .png, .pdf) created by the plugin from cacheDir and PICTURES directory.
    private fun cleanCache(result: Result) {
        try {
            if (::activity.isInitialized) {
                val picturesDir = activity.getExternalFilesDir(android.os.Environment.DIRECTORY_PICTURES)
                picturesDir?.listFiles()?.forEach { file ->
                    if (file.name.startsWith("DOCUMENT_SCAN_") || file.name.endsWith(".jpg") || file.name.endsWith(".png") || file.name.endsWith(".pdf")) {
                        file.delete()
                    }
                }
                activity.cacheDir?.listFiles()?.forEach { file ->
                    if (file.name.startsWith("DOCUMENT_SCAN_") || file.name.endsWith(".jpg") || file.name.endsWith(".png") || file.name.endsWith(".pdf")) {
                        file.delete()
                    }
                }
            }
            result.success(null)
        } catch (e: Exception) {
            result.error("CLEAN_CACHE_ERROR", e.localizedMessage, null)
        }
    }

    /// Called when the plugin is detached from the Flutter Engine.
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    /// Called when the plugin is attached to the host Activity.
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.activity = binding.activity
        addActivityResultListener(binding)
    }

    /// Starts the Android system gallery image picker intent.
    private fun startGalleryPicker() {
        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
            type = "image/*"
            addCategory(Intent.CATEGORY_OPENABLE)
        }
        try {
            ActivityCompat.startActivityForResult(activity, intent, START_GALLERY_PICKER, null)
        } catch (_: ActivityNotFoundException) {
            pendingResult?.error("ERROR", "Failed to start gallery picker", null)
        }
    }

    /// Registers the ActivityResultListener to handle image selection and scanning result intents.
    private fun addActivityResultListener(binding: ActivityPluginBinding) {
        this.binding = binding
        if (this.delegate == null) {
            this.delegate = PluginRegistry.ActivityResultListener { requestCode, resultCode, data ->
                android.util.Log.d("CunningScannerPlugin", "onActivityResult - requestCode: $requestCode, resultCode: $resultCode")
                if (requestCode != START_DOCUMENT_ACTIVITY && requestCode != START_DOCUMENT_FB_ACTIVITY && requestCode != START_GALLERY_PICKER) {
                    return@ActivityResultListener false
                }
                var handled = false
                var shouldClearPendingResult = false
                if (requestCode == START_GALLERY_PICKER) {
                    android.util.Log.d("CunningScannerPlugin", "Handling START_GALLERY_PICKER")
                    when (resultCode) {
                        Activity.RESULT_OK -> {
                            val selectedImageUri = data?.data
                            android.util.Log.d("CunningScannerPlugin", "Selected Image Uri: $selectedImageUri")
                            if (selectedImageUri != null) {
                                // Launch fallback cropper activity granting URI permission
                                val intent = Intent(activity, DocumentScannerActivity::class.java).apply {
                                    this.data = selectedImageUri
                                    this.clipData = ClipData.newRawUri("", selectedImageUri)
                                    this.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    putExtra("EXTRA_IMAGE_URI_TO_CROP", selectedImageUri.toString())
                                    putExtra(DocumentScannerExtra.EXTRA_MAX_NUM_DOCUMENTS, 1)
                                }
                                try {
                                    android.util.Log.d("CunningScannerPlugin", "Starting DocumentScannerActivity...")
                                    ActivityCompat.startActivityForResult(activity, intent, START_DOCUMENT_FB_ACTIVITY, null)
                                } catch (e: ActivityNotFoundException) {
                                    android.util.Log.e("CunningScannerPlugin", "Failed to start cropper: ${e.message}")
                                    pendingResult?.error("ERROR", "Failed to start cropper activity: ${e.message}", null)
                                    shouldClearPendingResult = true
                                }
                            } else {
                                android.util.Log.e("CunningScannerPlugin", "No image selected (Uri is null)")
                                pendingResult?.error("ERROR", "No image selected", null)
                                shouldClearPendingResult = true
                            }
                        }
                        Activity.RESULT_CANCELED -> {
                            android.util.Log.d("CunningScannerPlugin", "Gallery picker cancelled")
                            pendingResult?.success(emptyList<String>())
                            shouldClearPendingResult = true
                        }
                    }
                    handled = true
                } else if (requestCode == START_DOCUMENT_ACTIVITY) {
                    android.util.Log.d("CunningScannerPlugin", "Handling START_DOCUMENT_ACTIVITY (GMS)")
                    when (resultCode) {
                        Activity.RESULT_OK -> {
                            val error = data?.extras?.getString("error")
                            android.util.Log.d("CunningScannerPlugin", "GMS error extra: $error")
                            if (error != null) {
                                pendingResult?.error("ERROR", "error - $error", null)
                            } else {
                                 val scanningResult = data?.extras?.let { extras ->
                                     androidx.core.os.BundleCompat.getParcelable(
                                         extras,
                                         "extra_scanning_result",
                                         GmsDocumentScanningResult::class.java
                                     )
                                 } ?: return@ActivityResultListener false

                                if (asPdf) {
                                    val pdfUri = scanningResult.pdf?.uri?.toString()?.removePrefix("file://")
                                    android.util.Log.d("CunningScannerPlugin", "GMS PDF URI: $pdfUri")
                                    if (pdfUri != null) {
                                        pendingResult?.success(listOf(pdfUri))
                                    } else {
                                        pendingResult?.error("ERROR", "No PDF returned from ML Kit scanner", null)
                                    }
                                } else {
                                    val successResponse = scanningResult.pages?.map {
                                        it.imageUri.toString().removePrefix("file://")
                                    }?.toList()
                                    android.util.Log.d("CunningScannerPlugin", "GMS success response: $successResponse")
                                    pendingResult?.success(successResponse)
                                }
                            }
                            handled = true
                        }

                        Activity.RESULT_CANCELED -> {
                            android.util.Log.d("CunningScannerPlugin", "GMS scanner cancelled")
                            pendingResult?.success(emptyList<String>())
                            handled = true
                        }
                    }
                    shouldClearPendingResult = true
                } else {
                    android.util.Log.d("CunningScannerPlugin", "Handling START_DOCUMENT_FB_ACTIVITY (Fallback/HMS)")
                    when (resultCode) {
                        Activity.RESULT_OK -> {
                            val error = data?.extras?.getString("error")
                            android.util.Log.d("CunningScannerPlugin", "Cropper error extra: $error")
                            if (error != null) {
                                pendingResult?.error("ERROR", "error - $error", null)
                            } else {
                                val croppedImageResults =
                                    data?.getStringArrayListExtra("croppedImageResults")?.toList()
                                        ?: let {
                                            android.util.Log.e("CunningScannerPlugin", "No cropped images returned")
                                            pendingResult?.error("ERROR", "No cropped images returned", null)
                                            pendingResult = null
                                            return@ActivityResultListener true
                                        }
                                android.util.Log.d("CunningScannerPlugin", "Cropped image results: $croppedImageResults")

                                val successResponse = croppedImageResults.map {
                                    it.removePrefix("file://")
                                }.toList()
                                android.util.Log.d("CunningScannerPlugin", "Success response to Flutter: $successResponse")
                                if (asPdf) {
                                    try {
                                        val pdfFile = FileUtil().createPdfFile(activity)
                                        FileUtil().convertImagesToPdf(successResponse, pdfFile)
                                        successResponse.forEach { java.io.File(it).delete() }
                                        pendingResult?.success(listOf(pdfFile.absolutePath))
                                    } catch (e: Exception) {
                                        pendingResult?.error("ERROR", "Failed to create PDF from fallback scanner: ${e.message}", null)
                                    }
                                } else {
                                    pendingResult?.success(successResponse)
                                }
                            }
                            handled = true
                        }

                        Activity.RESULT_CANCELED -> {
                            android.util.Log.d("CunningScannerPlugin", "Cropper cancelled")
                            pendingResult?.success(emptyList<String>())
                            handled = true
                        }
                    }
                    shouldClearPendingResult = true
                }

                if (shouldClearPendingResult) {
                    android.util.Log.d("CunningScannerPlugin", "Clearing pendingResult")
                    pendingResult = null
                }
                return@ActivityResultListener handled
            }
        } else {
            binding.removeActivityResultListener(this.delegate!!)
        }

        binding.addActivityResultListener(delegate!!)
    }

    /// Creates an Intent to launch the fallback document scanner activity.
    private fun createDocumentScanIntent(noOfPages: Int): Intent {
        val documentScanIntent = Intent(activity, DocumentScannerActivity::class.java)

        documentScanIntent.putExtra(
            DocumentScannerExtra.EXTRA_MAX_NUM_DOCUMENTS,
            noOfPages
        )

        return documentScanIntent
    }

    /// Resolves GmsDocumentScannerOptions modes.
    private fun resolveScannerMode(mode: String?): Int {
        return when (mode) {
            "base" -> SCANNER_MODE_BASE
            "base_with_filter" -> SCANNER_MODE_BASE_WITH_FILTER
            "full", null -> SCANNER_MODE_FULL
            else -> SCANNER_MODE_FULL
        }
    }

    /// Configures GmsDocumentScannerOptions and launches GMS Document Scanner activity.
    private fun startScan(noOfPages: Int, isGalleryImportAllowed: Boolean, scannerMode: Int, asPdf: Boolean) {
        val optionsBuilder = GmsDocumentScannerOptions.Builder()
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
            scanner.getStartScanIntent(activity).addOnSuccessListener {
                try {
                    activity.startIntentSenderForResult(it, START_DOCUMENT_ACTIVITY, null, 0, 0, 0)
                } catch (_: IntentSender.SendIntentException) {
                    pendingResult?.error("ERROR", "Failed to start document scanner", null)
                }
            }.addOnFailureListener {
                openFallbackScanner(noOfPages)
            }
        } catch (_: Exception) {
            openFallbackScanner(noOfPages)
        }
    }

    /// Opens the fallback manual cropping scanner activity if GMS is unavailable.
    private fun openFallbackScanner(noOfPages: Int) {
        val intent = createDocumentScanIntent(noOfPages)
        try {
            ActivityCompat.startActivityForResult(
                this.activity,
                intent,
                START_DOCUMENT_FB_ACTIVITY,
                null
            )
        } catch (_: ActivityNotFoundException) {
            pendingResult?.error("ERROR", "FAILED TO START ACTIVITY", null)
        }
    }

    override fun onDetachedFromActivityForConfigChanges() {}

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        addActivityResultListener(binding)
    }

    override fun onDetachedFromActivity() {
        removeActivityResultListener()
    }

    /// Removes ActivityResultListener callback registrations.
    private fun removeActivityResultListener() {
        this.delegate?.let { this.binding?.removeActivityResultListener(it) }
    }
}
