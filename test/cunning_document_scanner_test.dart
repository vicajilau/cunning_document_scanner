// getPictures is deprecated but still supported, and its behaviour is tested here.
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _channel = MethodChannel('cunning_document_scanner');

/// The arguments of every call the mocked native side received, most recent last.
final List<MethodCall> _calls = <MethodCall>[];

/// Makes the native side answer every call with [handler].
void _mockNative(Object? Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (MethodCall call) async {
    _calls.add(call);
    return handler(call);
  });
}

/// Makes the native side complete every scan with [result].
void _mockScan(Map<String, Object?>? result) => _mockNative((_) => result);

Map<Object?, Object?> get _lastArguments =>
    _calls.last.arguments as Map<Object?, Object?>;

class _FakeScanner implements CunningDocumentScannerPlatform {
  int? noOfPages;
  ScannerSource? scannerSource;
  ScanOutput? output;
  bool cleaned = false;

  @override
  Future<ScanResult?> scanDocuments({
    required int noOfPages,
    required ScannerSource scannerSource,
    required ScanOutput output,
    required AndroidScannerMode androidScannerMode,
    IosScannerOptions? iosScannerOptions,
  }) async {
    this.noOfPages = noOfPages;
    this.scannerSource = scannerSource;
    this.output = output;
    return const ScanResult(images: <String>['/fake/page.jpg']);
  }

  @override
  Future<void> cleanCache() async => cleaned = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(_calls.clear);

  tearDown(() {
    // Mock handlers outlive the test that installed them.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('scanDocuments', () {
    test('sends the documented arguments, with defaults', () async {
      _mockScan(<String, Object?>{
        'images': <String>['/a.jpg']
      });

      await CunningDocumentScanner.scanDocuments();

      expect(_calls.single.method, 'scanDocuments');
      expect(_lastArguments, <String, Object?>{
        'noOfPages': 100,
        'scannerSource': 'camera',
        'output': 'images',
        'androidScannerMode': 'full',
      });
    });

    test('serializes every option', () async {
      _mockScan(<String, Object?>{'pdf': '/doc.pdf'});

      await CunningDocumentScanner.scanDocuments(
        noOfPages: 3,
        scannerSource: ScannerSource.cameraAndGallery,
        output: ScanOutput.imagesAndPdf,
        androidScannerMode: AndroidScannerMode.baseWithFilter,
        iosScannerOptions: IosScannerOptions(
          imageFormat: IosImageFormat.jpg,
          jpgCompressionQuality: 0.5,
          defaultFilter: IosDocumentFilter.blackAndWhite,
          showFilterBar: false,
        ),
      );

      expect(_lastArguments['noOfPages'], 3);
      expect(_lastArguments['scannerSource'], 'camera_and_gallery');
      expect(_lastArguments['output'], 'images_and_pdf');
      expect(_lastArguments['androidScannerMode'], 'base_with_filter');
      expect(_lastArguments['iosScannerOptions'], <String, Object?>{
        'imageFormat': 'jpg',
        'jpgCompressionQuality': 0.5,
        'defaultFilter': 'blackAndWhite',
        'showFilterBar': false,
      });
    });

    test('maps every ScanOutput to its channel value', () {
      expect(ScanOutput.images.methodChannelValue, 'images');
      expect(ScanOutput.pdf.methodChannelValue, 'pdf');
      expect(ScanOutput.imagesAndPdf.methodChannelValue, 'images_and_pdf');
    });

    test('returns images, PDF and discarded pages as a ScanResult', () async {
      _mockScan(<String, Object?>{
        'images': <String>['/a.jpg', '/b.jpg'],
        'pdf': '/doc.pdf',
        'discardedPages': 2,
      });

      final result = await CunningDocumentScanner.scanDocuments(
          output: ScanOutput.imagesAndPdf);

      expect(
        result,
        const ScanResult(
          images: <String>['/a.jpg', '/b.jpg'],
          pdf: '/doc.pdf',
          discardedPages: 2,
        ),
      );
    });

    test('reads a missing PDF and discarded count as null and 0', () async {
      _mockScan(<String, Object?>{
        'images': <String>['/a.jpg']
      });

      final result = await CunningDocumentScanner.scanDocuments();

      expect(result!.pdf, isNull);
      expect(result.discardedPages, 0);
    });

    test('returns null when the user cancels', () async {
      _mockScan(null);
      expect(await CunningDocumentScanner.scanDocuments(), isNull);
    });

    test('treats a result with no files as a cancellation', () async {
      _mockScan(<String, Object?>{'images': <String>[], 'discardedPages': 0});
      expect(await CunningDocumentScanner.scanDocuments(), isNull);
    });

    test('rejects a non-positive page limit before reaching native code',
        () async {
      _mockScan(null);
      expect(() => CunningDocumentScanner.scanDocuments(noOfPages: 0),
          throwsArgumentError);
      expect(() => CunningDocumentScanner.scanDocuments(noOfPages: -5),
          throwsArgumentError);
      expect(_calls, isEmpty);
    });

    test('maps a PlatformException to the package exception', () async {
      _mockNative((_) => throw PlatformException(
            code: 'permission_denied',
            message: 'Camera permission not granted',
          ));

      await expectLater(
        CunningDocumentScanner.scanDocuments(),
        throwsA(isA<CunningDocumentScannerException>()
            .having((e) => e.code, 'code', 'permission_denied')
            .having(
                (e) => e.message, 'message', 'Camera permission not granted')),
      );
    });

    test('surfaces a missing native plugin', () async {
      await expectLater(CunningDocumentScanner.scanDocuments(),
          throwsA(isA<MissingPluginException>()));
    });
  });

  group('getPictures (deprecated)', () {
    test('returns the page images', () async {
      _mockScan(<String, Object?>{
        'images': <String>['/a.jpg', '/b.jpg']
      });

      final pictures = await CunningDocumentScanner.getPictures();

      expect(pictures, <String>['/a.jpg', '/b.jpg']);
      expect(_lastArguments['output'], 'images');
    });

    test('still returns a growable list', () async {
      _mockScan(<String, Object?>{
        'images': <String>['/a.jpg']
      });

      final pictures = await CunningDocumentScanner.getPictures();
      pictures!.add('/extra.jpg');

      expect(pictures, hasLength(2));
    });

    test('returns the PDF as a single-element list with asPdf', () async {
      _mockScan(<String, Object?>{'pdf': '/doc.pdf'});

      final pictures = await CunningDocumentScanner.getPictures(asPdf: true);

      expect(pictures, <String>['/doc.pdf']);
      expect(_lastArguments['output'], 'pdf');
    });

    test('returns null when the user cancels', () async {
      _mockScan(null);
      expect(await CunningDocumentScanner.getPictures(), isNull);
    });

    test('resolves the deprecated isGalleryImportAllowed flag', () async {
      _mockScan(null);

      await CunningDocumentScanner.getPictures(isGalleryImportAllowed: true);
      expect(_lastArguments['scannerSource'], 'camera_and_gallery');

      await CunningDocumentScanner.getPictures(isGalleryImportAllowed: false);
      expect(_lastArguments['scannerSource'], 'camera');
    });

    test('prefers scannerSource over the deprecated flag', () async {
      _mockScan(null);

      await CunningDocumentScanner.getPictures(
        isGalleryImportAllowed: true,
        scannerSource: ScannerSource.gallery,
      );

      expect(_lastArguments['scannerSource'], 'gallery');
    });

    test('rejects a non-positive page limit', () {
      expect(() => CunningDocumentScanner.getPictures(noOfPages: 0),
          throwsArgumentError);
    });
  });

  group('cleanCache', () {
    test('calls the native method', () async {
      _mockNative((_) => null);

      await CunningDocumentScanner.cleanCache();

      expect(_calls.single.method, 'cleanCache');
    });

    test('maps a PlatformException to the package exception', () async {
      _mockNative((_) => throw PlatformException(
            code: 'CLEAN_CACHE_ERROR',
            message: 'Permission denied',
          ));

      await expectLater(
        CunningDocumentScanner.cleanCache(),
        throwsA(isA<CunningDocumentScannerException>()
            .having((e) => e.code, 'code', 'CLEAN_CACHE_ERROR')),
      );
    });
  });

  group('CunningDocumentScannerPlatform', () {
    late CunningDocumentScannerPlatform original;

    setUp(() => original = CunningDocumentScannerPlatform.instance);
    tearDown(() => CunningDocumentScannerPlatform.instance = original);

    test('defaults to the method channel implementation', () {
      expect(CunningDocumentScannerPlatform.instance,
          isA<MethodChannelCunningDocumentScanner>());
    });

    test('routes every call to a replaced instance', () async {
      final fake = _FakeScanner();
      CunningDocumentScannerPlatform.instance = fake;

      final result = await CunningDocumentScanner.scanDocuments(
        noOfPages: 4,
        scannerSource: ScannerSource.gallery,
        output: ScanOutput.pdf,
      );
      await CunningDocumentScanner.cleanCache();

      expect(result!.images, <String>['/fake/page.jpg']);
      expect(fake.noOfPages, 4);
      expect(fake.scannerSource, ScannerSource.gallery);
      expect(fake.output, ScanOutput.pdf);
      expect(fake.cleaned, isTrue);
      expect(_calls, isEmpty);
    });

    test('still validates arguments before a replaced instance', () {
      CunningDocumentScannerPlatform.instance = _FakeScanner();
      expect(() => CunningDocumentScanner.scanDocuments(noOfPages: 0),
          throwsArgumentError);
    });
  });

  group('ScanResult', () {
    test('compares by value', () {
      expect(
        const ScanResult(images: <String>['/a.jpg'], pdf: '/d.pdf'),
        const ScanResult(images: <String>['/a.jpg'], pdf: '/d.pdf'),
      );
      expect(
        const ScanResult(images: <String>['/a.jpg']).hashCode,
        const ScanResult(images: <String>['/a.jpg']).hashCode,
      );
      expect(
        const ScanResult(images: <String>['/a.jpg']),
        isNot(const ScanResult(images: <String>['/b.jpg'])),
      );
    });

    test('exposes an unmodifiable image list when built from a map', () {
      final result = ScanResult.fromMap(<Object?, Object?>{
        'images': <Object?>['/a.jpg']
      });
      expect(() => result.images.add('/b.jpg'), throwsUnsupportedError);
    });
  });

  group('IosScannerOptions', () {
    test('rejects an out-of-range compression quality', () {
      expect(() => IosScannerOptions(jpgCompressionQuality: 1.5),
          throwsArgumentError);
      expect(() => IosScannerOptions(jpgCompressionQuality: -0.1),
          throwsArgumentError);
    });
  });
}
