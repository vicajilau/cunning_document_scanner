import 'ios_document_filter.dart';
import 'ios_image_format.dart';

/// Different options that modify the behavior of the document scanner on iOS.
///
/// The [imageFormat] specifies the format of the output image file. Available
/// options are [IosImageFormat.jpg] or [IosImageFormat.png]. Default value is
/// [IosImageFormat.png].
///
/// If [imageFormat] is set to [IosImageFormat.jpg] the [jpgCompressionQuality]
/// can be used to control the quality of the resulting JPEG image. The value
/// 0.0 represents the maximum compression (or lowest quality) while the value
/// 1.0 represents the least compression (or best quality). Default value is 1.0.
///
/// [defaultFilter] and [showFilterBar] configure the filter selector of the
/// custom cropper shown for gallery imports.
final class IosScannerOptions {
  /// Creates a [IosScannerOptions].
  ///
  /// Throws an [ArgumentError] if [jpgCompressionQuality] is outside 0.0 - 1.0.
  IosScannerOptions({
    this.imageFormat = IosImageFormat.png,
    this.jpgCompressionQuality = 1.0,
    this.defaultFilter = IosDocumentFilter.original,
    this.showFilterBar = true,
  }) {
    if (jpgCompressionQuality < 0.0 || jpgCompressionQuality > 1.0) {
      throw ArgumentError.value(
        jpgCompressionQuality,
        'jpgCompressionQuality',
        'jpgCompressionQuality must be between 0.0 and 1.0',
      );
    }
  }

  /// The file format used to write the scanned pages.
  final IosImageFormat imageFormat;

  /// The quality of the resulting JPEG image, expressed as a value from 0.0 to
  /// 1.0.
  ///
  /// The value 0.0 represents the maximum compression (or lowest quality) while
  /// the value 1.0 represents the least compression (or best quality). The
  /// [jpgCompressionQuality] only has an effect if the [imageFormat] is set to
  /// [IosImageFormat.jpg] and is ignored otherwise.
  final double jpgCompressionQuality;

  /// The filter preselected for every page in the custom cropper.
  ///
  /// Only applies to images imported from the gallery, which go through the
  /// plugin's own cropper. Defaults to [IosDocumentFilter.original].
  final IosDocumentFilter defaultFilter;

  /// Whether the user may change the filter from the cropper.
  ///
  /// When false the filter selector is hidden and every page keeps
  /// [defaultFilter]. Defaults to true.
  final bool showFilterBar;

  /// Serializes these options for the method channel.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'imageFormat': imageFormat.name,
        'jpgCompressionQuality': jpgCompressionQuality,
        'defaultFilter': defaultFilter.methodChannelValue,
        'showFilterBar': showFilterBar,
      };
}
