package biz.cunning.cunning_document_scanner.fallback.constants

// / Holds keys for Intent Extras passed to the fallback DocumentScannerActivity.
class DocumentScannerExtra {
    companion object {
        // / Intent extra key for cropped image quality integer setting.
        const val EXTRA_CROPPED_IMAGE_QUALITY = "croppedImageQuality"

        // / Intent extra key for the maximum number of pages allowed.
        const val EXTRA_MAX_NUM_DOCUMENTS = "maxNumDocuments"

        // / Intent extra key holding the gallery image URIs to crop, as an ArrayList<String>.
        const val EXTRA_IMAGE_URIS_TO_CROP = "imageUrisToCrop"

        // / Legacy single-URI extra, kept so older intents keep working.
        const val EXTRA_IMAGE_URI_TO_CROP = "EXTRA_IMAGE_URI_TO_CROP"
    }
}
