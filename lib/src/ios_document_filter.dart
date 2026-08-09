/// Image filters the iOS cropper can apply to a scanned page.
///
/// These are only used by the custom cropper shown for gallery imports. The
/// system document camera (`VNDocumentCameraViewController`) applies its own
/// filtering and does not expose a toggle.
enum IosDocumentFilter {
  /// Leaves the page exactly as captured.
  original,

  /// Enhances contrast and saturation, keeping colours.
  color,

  /// Converts the page to shades of grey.
  grayscale,

  /// Converts the page to pure black and white, maximising text legibility.
  blackAndWhite,
}

/// Serialization of [IosDocumentFilter] for the method channel.
extension IosDocumentFilterValue on IosDocumentFilter {
  /// The identifier sent over the method channel.
  String get methodChannelValue {
    switch (this) {
      case IosDocumentFilter.original:
        return 'original';
      case IosDocumentFilter.color:
        return 'color';
      case IosDocumentFilter.grayscale:
        return 'grayscale';
      case IosDocumentFilter.blackAndWhite:
        return 'blackAndWhite';
    }
  }
}
