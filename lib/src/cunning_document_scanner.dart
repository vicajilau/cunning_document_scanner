import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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
  /// Returns a list of paths to the scanned images, or null if the user cancels the operation.
  ///
  /// Throws an [ArgumentError] if [noOfPages] is less than or equal to 0.
  /// Throws a [CunningDocumentScannerException] if camera permission is denied or a scanning error occurs.
  static Future<List<String>?> getPictures({
    int noOfPages = 100,
    @Deprecated('Use scannerSource instead')
    bool isGalleryImportAllowed = false,
    ScannerSource? scannerSource,
    AndroidScannerMode? androidScannerMode = AndroidScannerMode.full,
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

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
      ].request();
      if (statuses.containsValue(PermissionStatus.denied) ||
          statuses.containsValue(PermissionStatus.permanentlyDenied)) {
        throw const CunningDocumentScannerException.permissionDenied(
            'Camera permission not granted');
      }
    }

    final resolvedSource = scannerSource ??
        (isGalleryImportAllowed
            ? ScannerSource.cameraAndGallery
            : ScannerSource.camera);

    if (kDebugMode) {
      print(
          "CunningDocumentScanner: scannerSource=$scannerSource, resolvedSource=$resolvedSource, methodChannelValue=${resolvedSource.methodChannelValue}");
    }

    final List<dynamic>? pictures = await _channel.invokeMethod('getPictures', {
      'noOfPages': noOfPages,
      'isGalleryImportAllowed': isGalleryImportAllowed,
      'scannerSource': resolvedSource.methodChannelValue,
      'androidScannerMode': androidScannerMode?.methodChannelValue,
      'asPdf': asPdf,
      if (iosScannerOptions != null)
        'iosScannerOptions': {
          'imageFormat': iosScannerOptions.imageFormat.name,
          'jpgCompressionQuality': iosScannerOptions.jpgCompressionQuality,
        }
    });
    return pictures?.map((e) => e as String).toList();
  }

  /// Clears temporary scanned images and generated PDF files from cache.
  static Future<void> cleanCache() async {
    await _channel.invokeMethod('cleanCache');
  }
}
