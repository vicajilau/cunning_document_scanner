import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CunningDocumentScanner camera permission', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    // The permission is requested natively (AVCaptureDevice on iOS), so what Dart
    // owns is translating the native refusal into the documented exception.
    testWidgets('a denied permission surfaces as the documented exception',
        (WidgetTester tester) async {
      const MethodChannel channel = MethodChannel('cunning_document_scanner');

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) => throw PlatformException(
          code: 'permission_denied',
          message: 'Camera permission not granted',
        ),
      );

      await expectLater(
        CunningDocumentScanner.getPictures(),
        throwsA(isA<CunningDocumentScannerException>()
            .having((e) => e.code, 'code', 'permission_denied')
            .having(
                (e) => e.message, 'message', 'Camera permission not granted')),
      );

      // Mock handlers outlive the test that installed them, and the next group
      // relies on the channel having none.
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
  });

  group('CunningDocumentScanner Plugin exceptions', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    test('getPictures with MissingPluginException', () async {
      expect(() async => await CunningDocumentScanner.getPictures(),
          throwsA(isA<MissingPluginException>()));
    });
  });

  group('CunningDocumentScanner granted permission', () {
    setUp(TestWidgetsFlutterBinding.ensureInitialized);

    void loadPlatformChannel(WidgetTester tester, List<String> result) {
      const MethodChannel channel = MethodChannel('cunning_document_scanner');

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) => Future.value(result),
      );
    }

    testWidgets('getPictures normalizes an empty native result to null',
        (WidgetTester tester) async {
      // Android reports cancellation as an empty list, iOS as null. Callers see null
      // on both platforms so a single null check is enough.
      loadPlatformChannel(tester, <String>[]);
      final result = await CunningDocumentScanner.getPictures();
      expect(result, isNull);
    });

    testWidgets('getPictures multiple result', (WidgetTester tester) async {
      final List<String> fakeResult = ['fake_url1', 'fake_url2', 'fake_url3'];
      loadPlatformChannel(tester, fakeResult);
      final result = await CunningDocumentScanner.getPictures();
      expect(result, fakeResult);
    });

    testWidgets('getPictures passes asPdf parameter',
        (WidgetTester tester) async {
      final List<String> fakeResult = ['fake_pdf_url'];
      const MethodChannel channel = MethodChannel('cunning_document_scanner');

      bool passedAsPdf = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) {
          passedAsPdf =
              (methodCall.arguments as Map)['asPdf'] as bool? ?? false;
          return Future.value(fakeResult);
        },
      );

      final result = await CunningDocumentScanner.getPictures(asPdf: true);
      expect(result, fakeResult);
      expect(passedAsPdf, isTrue);
    });

    testWidgets('getPictures resolves scannerSource when explicitly provided',
        (WidgetTester tester) async {
      final List<String> fakeResult = ['fake_url'];
      const MethodChannel channel = MethodChannel('cunning_document_scanner');

      String? passedSource;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) {
          passedSource =
              (methodCall.arguments as Map)['scannerSource'] as String?;
          return Future.value(fakeResult);
        },
      );

      await CunningDocumentScanner.getPictures(
          scannerSource: ScannerSource.gallery);
      expect(passedSource, equals('gallery'));

      await CunningDocumentScanner.getPictures(
          scannerSource: ScannerSource.camera);
      expect(passedSource, equals('camera'));
    });

    testWidgets(
        'getPictures fallback to isGalleryImportAllowed when scannerSource is null',
        (WidgetTester tester) async {
      final List<String> fakeResult = ['fake_url'];
      const MethodChannel channel = MethodChannel('cunning_document_scanner');

      String? passedSource;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) {
          passedSource =
              (methodCall.arguments as Map)['scannerSource'] as String?;
          return Future.value(fakeResult);
        },
      );

      await CunningDocumentScanner.getPictures(isGalleryImportAllowed: true);
      expect(passedSource, equals('camera_and_gallery'));

      await CunningDocumentScanner.getPictures(isGalleryImportAllowed: false);
      expect(passedSource, equals('camera'));
    });

    testWidgets('cleanCache calls native methodChannel',
        (WidgetTester tester) async {
      const MethodChannel channel = MethodChannel('cunning_document_scanner');

      bool cleanCacheCalled = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) {
          if (methodCall.method == 'cleanCache') {
            cleanCacheCalled = true;
            return Future.value(null);
          }
          return Future.value(null);
        },
      );

      await CunningDocumentScanner.cleanCache();
      expect(cleanCacheCalled, isTrue);
    });

    testWidgets('getPictures throws ArgumentError when noOfPages is <= 0',
        (WidgetTester tester) async {
      expect(
        () => CunningDocumentScanner.getPictures(noOfPages: 0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => CunningDocumentScanner.getPictures(noOfPages: -5),
        throwsA(isA<ArgumentError>()),
      );
    });

    testWidgets('getPictures maps a PlatformException to the package exception',
        (WidgetTester tester) async {
      const MethodChannel channel = MethodChannel('cunning_document_scanner');

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) => throw PlatformException(
          code: 'ALREADY_ACTIVE',
          message: 'A document scan is already in progress',
        ),
      );

      await expectLater(
        CunningDocumentScanner.getPictures(),
        throwsA(isA<CunningDocumentScannerException>()
            .having((e) => e.code, 'code', 'ALREADY_ACTIVE')
            .having((e) => e.message, 'message',
                'A document scan is already in progress')),
      );
    });

    testWidgets('cleanCache maps a PlatformException to the package exception',
        (WidgetTester tester) async {
      const MethodChannel channel = MethodChannel('cunning_document_scanner');

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) => throw PlatformException(
          code: 'CLEAN_CACHE_ERROR',
          message: 'Permission denied',
        ),
      );

      await expectLater(
        CunningDocumentScanner.cleanCache(),
        throwsA(isA<CunningDocumentScannerException>()
            .having((e) => e.code, 'code', 'CLEAN_CACHE_ERROR')),
      );
    });

    testWidgets('getPictures forwards the default androidScannerMode',
        (WidgetTester tester) async {
      const MethodChannel channel = MethodChannel('cunning_document_scanner');

      String? passedMode;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) {
          passedMode =
              (methodCall.arguments as Map)['androidScannerMode'] as String?;
          return Future.value(<String>['fake_url']);
        },
      );

      await CunningDocumentScanner.getPictures();
      expect(passedMode, equals('full'));

      await CunningDocumentScanner.getPictures(
          androidScannerMode: AndroidScannerMode.baseWithFilter);
      expect(passedMode, equals('base_with_filter'));
    });

    testWidgets('getPictures serializes the iOS scanner options',
        (WidgetTester tester) async {
      const MethodChannel channel = MethodChannel('cunning_document_scanner');

      Map<dynamic, dynamic>? passedOptions;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) {
          passedOptions = (methodCall.arguments as Map)['iosScannerOptions']
              as Map<dynamic, dynamic>?;
          return Future.value(<String>['fake_url']);
        },
      );

      await CunningDocumentScanner.getPictures(
        iosScannerOptions: IosScannerOptions(
          imageFormat: IosImageFormat.jpg,
          jpgCompressionQuality: 0.5,
          defaultFilter: IosDocumentFilter.blackAndWhite,
          showFilterBar: false,
        ),
      );

      expect(passedOptions, isNotNull);
      expect(passedOptions!['imageFormat'], equals('jpg'));
      expect(passedOptions!['jpgCompressionQuality'], equals(0.5));
      expect(passedOptions!['defaultFilter'], equals('blackAndWhite'));
      expect(passedOptions!['showFilterBar'], isFalse);
    });

    test('IosScannerOptions rejects an out-of-range compression quality', () {
      expect(
        () => IosScannerOptions(jpgCompressionQuality: 1.5),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => IosScannerOptions(jpgCompressionQuality: -0.1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
