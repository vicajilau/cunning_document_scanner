import 'dart:async';

import 'package:flutter/services.dart';

import 'android_scanner_mode.dart';
import 'exceptions.dart';
import 'ios_scanner_options.dart';
import 'scanner_source.dart';

/// A class that provides a simple way to scan documents.
class CunningDocumentScanner {
  /// The method channel used to interact with the native platform.
  static const MethodChannel _channel =
      MethodChannel('cunning_document_scanner');

  /// Starts the document scanning process.
  ///
  /// This method will open the camera and allow the user to scan documents.
  ///
  /// [noOfPages] is the maximum number of pages that can be scanned (must be > 0).
  /// [isGalleryImportAllowed] is deprecated, use [scannerSource] instead.
  /// [scannerSource] controls where images are sourced from (camera, gallery, or both).
  /// [androidScannerMode] controls the ML Kit scanner mode on Android only.
  /// [iosScannerOptions] is a set of options for the iOS scanner.
  /// [asPdf] is a flag that indicates if the scanned pages should be compiled and returned as a single PDF file path.
  ///
  /// Returns a list of paths to the scanned images, or null if the user cancels
  /// the operation. Cancellation reports null on every platform.
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
  static Future<List<String>?> getPictures({
    int noOfPages = 100,
    @Deprecated('Use scannerSource instead')
    bool isGalleryImportAllowed = false,
    ScannerSource? scannerSource,
    AndroidScannerMode androidScannerMode = AndroidScannerMode.full,
    IosScannerOptions? iosScannerOptions,
    bool asPdf = false,
  }) async {
    if (noOfPages <= 0) {
      throw ArgumentError.value(
        noOfPages,
        'noOfPages',
        'noOfPages must be greater than 0',
      );
    }

    final resolvedSource = scannerSource ??
        (isGalleryImportAllowed
            ? ScannerSource.cameraAndGallery
            : ScannerSource.camera);

    final List<dynamic>? pictures;
    try {
      pictures = await _channel.invokeMethod<List<dynamic>>('getPictures', {
        'noOfPages': noOfPages,
        'isGalleryImportAllowed': isGalleryImportAllowed,
        'scannerSource': resolvedSource.methodChannelValue,
        'androidScannerMode': androidScannerMode.methodChannelValue,
        'asPdf': asPdf,
        if (iosScannerOptions != null)
          'iosScannerOptions': iosScannerOptions.toMap(),
      });
    } on PlatformException catch (e) {
      // The native side reports failures as PlatformException. Surfacing them as
      // the package's own exception keeps callers on a single catch clause.
      throw CunningDocumentScannerException(
        e.message ?? 'The document scan failed',
        code: e.code,
      );
    }

    // Android historically reported cancellation as an empty list while iOS
    // reported null. Both are normalized to null here.
    if (pictures == null || pictures.isEmpty) {
      return null;
    }
    return pictures.map((e) => e as String).toList();
  }

  /// Clears the temporary scanned images and generated PDF files this plugin created.
  ///
  /// Only files written by the plugin are removed; files belonging to the host
  /// application are left untouched.
  ///
  /// Throws a [CunningDocumentScannerException] if the files cannot be removed.
  static Future<void> cleanCache() async {
    try {
      await _channel.invokeMethod<void>('cleanCache');
    } on PlatformException catch (e) {
      throw CunningDocumentScannerException(
        e.message ?? 'Failed to clean the scanner cache',
        code: e.code,
      );
    }
  }
}
