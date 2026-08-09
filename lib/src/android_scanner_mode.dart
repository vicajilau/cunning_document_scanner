/// Android-only scanner modes for ML Kit document scanning.
enum AndroidScannerMode {
  /// Full feature set including ML-based enhancements.
  full,

  /// Basic scan pipeline without filters.
  base,

  /// Basic scan pipeline with filters.
  baseWithFilter,
}

/// Serialization of [AndroidScannerMode] for the method channel.
extension AndroidScannerModeValue on AndroidScannerMode {
  /// The identifier sent over the method channel.
  String get methodChannelValue {
    switch (this) {
      case AndroidScannerMode.full:
        return 'full';
      case AndroidScannerMode.base:
        return 'base';
      case AndroidScannerMode.baseWithFilter:
        return 'base_with_filter';
    }
  }
}
