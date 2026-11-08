/// The files a scan produces.
enum ScanOutput {
  /// One image file per scanned page.
  images,

  /// A single PDF document holding every scanned page.
  pdf,

  /// Both the page images and a PDF document built from them.
  imagesAndPdf,
}

/// Serialization of [ScanOutput] for the method channel.
extension ScanOutputValue on ScanOutput {
  /// The identifier sent over the method channel.
  String get methodChannelValue {
    switch (this) {
      case ScanOutput.images:
        return 'images';
      case ScanOutput.pdf:
        return 'pdf';
      case ScanOutput.imagesAndPdf:
        return 'images_and_pdf';
    }
  }
}
