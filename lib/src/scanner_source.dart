/// The source from which the document scanner acquires images.
enum ScannerSource {
  /// Launches the camera only, disabling gallery selection.
  camera,

  /// Launches the gallery picker directly.
  gallery,

  /// Launches a menu (iOS) or shows a gallery shortcut (Android) allowing the user to select either.
  cameraAndGallery,
}

/// Serialization of [ScannerSource] for the method channel.
extension ScannerSourceValue on ScannerSource {
  /// The identifier sent over the method channel.
  String get methodChannelValue {
    switch (this) {
      case ScannerSource.camera:
        return 'camera';
      case ScannerSource.gallery:
        return 'gallery';
      case ScannerSource.cameraAndGallery:
        return 'camera_and_gallery';
    }
  }
}
