import 'dart:async';

import 'android_scanner_mode.dart';
import 'cunning_document_scanner_platform.dart';
import 'exceptions.dart';
import 'ios_scanner_options.dart';
import 'scan_output.dart';
import 'scan_result.dart';
import 'scanner_source.dart';

/// A class that provides a simple way to scan documents.
class CunningDocumentScanner {
  /// Scans one or more document pages.
  ///
  /// [noOfPages] is the maximum number of pages the result may hold (must be > 0).
  /// Android's scanner and the iOS photo picker enforce it while the user scans.
  /// The iOS document camera and the Android gallery picker cannot, so pages past
  /// the limit are dropped and counted in [ScanResult.discardedPages].
  ///
  /// [scannerSource] controls where pages come from: camera, gallery, or a choice
  /// of both.
  ///
  /// [output] selects the files produced: page images, a single PDF, or both.
  ///
  /// [androidScannerMode] controls the ML Kit scanner mode on Android only.
  ///
  /// [iosScannerOptions] configures the image format and cropper on iOS only.
  ///
  /// Returns null if the user cancels, on every platform.
  ///
  /// The returned files live in a plugin-owned cache directory and are removed by
  /// [cleanCache]. Copy anything you need to keep to your own storage.
  ///
  /// On iOS the camera permission is requested natively, and only when the flow
  /// actually opens the camera. [ScannerSource.gallery] uses the system photo
  /// picker, which requires no permission and prompts for nothing.
  ///
  /// Throws an [ArgumentError] if [noOfPages] is less than or equal to 0.
  /// Throws a [CunningDocumentScannerException] if camera permission is denied
  /// (with `code` `'permission_denied'`) or a scanning error occurs.
  static Future<ScanResult?> scanDocuments({
    int noOfPages = 100,
    ScannerSource scannerSource = ScannerSource.camera,
    ScanOutput output = ScanOutput.images,
    AndroidScannerMode androidScannerMode = AndroidScannerMode.full,
    IosScannerOptions? iosScannerOptions,
  }) {
    if (noOfPages <= 0) {
      throw ArgumentError.value(
        noOfPages,
        'noOfPages',
        'noOfPages must be greater than 0',
      );
    }

    return CunningDocumentScannerPlatform.instance.scanDocuments(
      noOfPages: noOfPages,
      scannerSource: scannerSource,
      output: output,
      androidScannerMode: androidScannerMode,
      iosScannerOptions: iosScannerOptions,
    );
  }

  /// Starts the document scanning process.
  ///
  /// Prefer [scanDocuments], which returns a [ScanResult] that tells images and
  /// PDF apart, can produce both at once, and reports pages dropped for exceeding
  /// [noOfPages].
  ///
  /// [noOfPages] is the maximum number of pages that can be scanned (must be > 0).
  /// The iOS document camera exposes no page limit, so extra pages are discarded
  /// after the fact without telling the caller.
  /// [isGalleryImportAllowed] is deprecated, use [scannerSource] instead.
  /// [scannerSource] controls where images are sourced from (camera, gallery, or both).
  /// [androidScannerMode] controls the ML Kit scanner mode on Android only.
  /// [iosScannerOptions] is a set of options for the iOS scanner.
  /// [asPdf] returns a single-element list holding the path of a PDF instead of
  /// the page images.
  ///
  /// Returns a list of paths, or null if the user cancels the operation.
  ///
  /// Throws an [ArgumentError] if [noOfPages] is less than or equal to 0.
  /// Throws a [CunningDocumentScannerException] if camera permission is denied
  /// (with `code` `'permission_denied'`) or a scanning error occurs.
  @Deprecated('Use scanDocuments instead, which returns a typed ScanResult. '
      'This method will be removed in 4.0.0.')
  static Future<List<String>?> getPictures({
    int noOfPages = 100,
    @Deprecated('Use scannerSource instead')
    bool isGalleryImportAllowed = false,
    ScannerSource? scannerSource,
    AndroidScannerMode androidScannerMode = AndroidScannerMode.full,
    IosScannerOptions? iosScannerOptions,
    bool asPdf = false,
  }) async {
    final result = await scanDocuments(
      noOfPages: noOfPages,
      scannerSource: scannerSource ??
          (isGalleryImportAllowed
              ? ScannerSource.cameraAndGallery
              : ScannerSource.camera),
      output: asPdf ? ScanOutput.pdf : ScanOutput.images,
      androidScannerMode: androidScannerMode,
      iosScannerOptions: iosScannerOptions,
    );
    if (result == null) return null;
    final pdf = result.pdf;
    // Callers of this method have always received a growable list of their own.
    return asPdf
        ? (pdf == null ? null : <String>[pdf])
        : result.images.toList();
  }

  /// Clears the temporary scanned images and generated PDF files this plugin created.
  ///
  /// Only files written by the plugin are removed; files belonging to the host
  /// application are left untouched.
  ///
  /// Throws a [CunningDocumentScannerException] if the files cannot be removed.
  static Future<void> cleanCache() =>
      CunningDocumentScannerPlatform.instance.cleanCache();
}
