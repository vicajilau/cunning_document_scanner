import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'android_scanner_mode.dart';
import 'exceptions.dart';
import 'ios_scanner_options.dart';
import 'scan_output.dart';
import 'scan_result.dart';
import 'scanner_source.dart';

/// The platform implementation behind `CunningDocumentScanner`.
///
/// Replace [instance] in your own tests to drive the scanner without a device:
///
/// ```dart
/// class FakeScanner implements CunningDocumentScannerPlatform {
///   @override
///   Future<ScanResult?> scanDocuments({...}) async =>
///       const ScanResult(images: ['/tmp/page.jpg']);
///
///   @override
///   Future<void> cleanCache() async {}
/// }
///
/// setUp(() => CunningDocumentScannerPlatform.instance = FakeScanner());
/// ```
abstract class CunningDocumentScannerPlatform {
  /// The implementation every `CunningDocumentScanner` call is routed to.
  ///
  /// Defaults to [MethodChannelCunningDocumentScanner].
  static CunningDocumentScannerPlatform get instance => _instance;

  /// Replaces the implementation, typically with a fake in tests.
  @visibleForTesting
  static set instance(CunningDocumentScannerPlatform instance) {
    _instance = instance;
  }

  static CunningDocumentScannerPlatform _instance =
      MethodChannelCunningDocumentScanner();

  /// Runs a scan with arguments the caller has already validated.
  ///
  /// Returns null when the user cancels.
  Future<ScanResult?> scanDocuments({
    required int noOfPages,
    required ScannerSource scannerSource,
    required ScanOutput output,
    required AndroidScannerMode androidScannerMode,
    IosScannerOptions? iosScannerOptions,
  });

  /// Removes every file the plugin has written.
  Future<void> cleanCache();
}

/// The [CunningDocumentScannerPlatform] that talks to the native plugin.
class MethodChannelCunningDocumentScanner
    extends CunningDocumentScannerPlatform {
  /// The method channel shared with the native Android and iOS code.
  @visibleForTesting
  static const MethodChannel channel =
      MethodChannel('cunning_document_scanner');

  @override
  Future<ScanResult?> scanDocuments({
    required int noOfPages,
    required ScannerSource scannerSource,
    required ScanOutput output,
    required AndroidScannerMode androidScannerMode,
    IosScannerOptions? iosScannerOptions,
  }) async {
    final Map<Object?, Object?>? result;
    try {
      result = await channel.invokeMethod<Map<Object?, Object?>>(
        'scanDocuments',
        <String, Object?>{
          'noOfPages': noOfPages,
          'scannerSource': scannerSource.methodChannelValue,
          'output': output.methodChannelValue,
          'androidScannerMode': androidScannerMode.methodChannelValue,
          if (iosScannerOptions != null)
            'iosScannerOptions': iosScannerOptions.toMap(),
        },
      );
    } on PlatformException catch (e) {
      // The native side reports failures as PlatformException. Surfacing them as
      // the package's own exception keeps callers on a single catch clause.
      throw CunningDocumentScannerException(
        e.message ?? 'The document scan failed',
        code: e.code,
      );
    }

    if (result == null) return null;
    final scan = ScanResult.fromMap(result);
    // A scan that produced nothing is a cancellation in all but name.
    if (scan.images.isEmpty && scan.pdf == null) return null;
    return scan;
  }

  @override
  Future<void> cleanCache() async {
    try {
      await channel.invokeMethod<void>('cleanCache');
    } on PlatformException catch (e) {
      throw CunningDocumentScannerException(
        e.message ?? 'Failed to clean the scanner cache',
        code: e.code,
      );
    }
  }
}
