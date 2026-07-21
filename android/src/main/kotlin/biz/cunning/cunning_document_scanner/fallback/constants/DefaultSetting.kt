package biz.cunning.cunning_document_scanner.fallback.constants

// / Holds default fallback configuration parameters.
class DefaultSetting {
    companion object {
        // / Default output compression quality (100 is lossless/highest quality).
        const val CROPPED_IMAGE_QUALITY = 100

        // / Default limit on the maximum number of pages a user can scan.
        const val MAX_NUM_DOCUMENTS = 24
    }
}
