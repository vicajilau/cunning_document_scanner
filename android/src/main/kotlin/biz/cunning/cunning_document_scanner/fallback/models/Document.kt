package biz.cunning.cunning_document_scanner.fallback.models

/// Represents a scanned document, holding the file path, size dimensions, and cropping corner coordinates.
///
/// @param originalPhotoFilePath The local file path to the original un-cropped photo.
/// @param originalPhotoWidth The width of the original photo in pixels.
/// @param originalPhotoHeight The height of the original photo in pixels.
/// @param corners The Quad representation of the four crop corner coordinates.
class Document(
    val originalPhotoFilePath: String,
    private val originalPhotoWidth: Int,
    val originalPhotoHeight: Int,
    var corners: Quad
) {
}