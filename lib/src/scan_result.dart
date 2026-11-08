import 'package:flutter/foundation.dart';

/// The outcome of a completed document scan.
///
/// Which fields are filled depends on the [ScanOutput] requested:
/// [images] is empty when only a PDF was asked for, and [pdf] is null when only
/// images were.
///
/// Every path points into a plugin-owned cache directory that
/// `CunningDocumentScanner.cleanCache` empties. Copy anything you need to keep to
/// your own storage.
@immutable
final class ScanResult {
  /// Creates a [ScanResult].
  const ScanResult({
    this.images = const <String>[],
    this.pdf,
    this.discardedPages = 0,
  });

  /// Builds a [ScanResult] from the map the native side returns.
  factory ScanResult.fromMap(Map<Object?, Object?> map) {
    final images = map['images'] as List<Object?>? ?? const <Object?>[];
    return ScanResult(
      images: List<String>.unmodifiable(images.cast<String>()),
      pdf: map['pdf'] as String?,
      discardedPages: map['discardedPages'] as int? ?? 0,
    );
  }

  /// Absolute paths to the page images, in page order.
  final List<String> images;

  /// Absolute path to the PDF document, or null if no PDF was requested.
  final String? pdf;

  /// How many pages the user scanned or picked beyond `noOfPages`.
  ///
  /// Those pages are not part of [images] or [pdf]. Only flows that cannot enforce
  /// the limit while the user is scanning report anything here: the iOS document
  /// camera and the Android gallery picker. Everywhere else it is always 0.
  final int discardedPages;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanResult &&
          listEquals(images, other.images) &&
          pdf == other.pdf &&
          discardedPages == other.discardedPages;

  @override
  int get hashCode => Object.hash(Object.hashAll(images), pdf, discardedPages);

  @override
  String toString() =>
      'ScanResult(images: $images, pdf: $pdf, discardedPages: $discardedPages)';
}
