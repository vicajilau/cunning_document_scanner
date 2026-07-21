import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

import 'mocks/mock_permission_handler_platform.dart';

void main() {
  group('CunningDocumentScanner permission denied', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      PermissionHandlerPlatform.instance = MockPermissionHandlerPlatform(
          permissionStatus: PermissionStatus.denied);
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('getPictures with denied permission', () async {
      expect(
        () async => await CunningDocumentScanner.getPictures(),
        throwsA(isA<CunningDocumentScannerException>()
            .having((e) => e.code, 'code', 'permission_denied')
            .having(
                (e) => e.message, 'message', 'Camera permission not granted')),
      );
    });
  });

  group('CunningDocumentScanner permission permanently denied', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      PermissionHandlerPlatform.instance = MockPermissionHandlerPlatform(
          permissionStatus: PermissionStatus.permanentlyDenied);
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('getPictures with permanently denied permission', () async {
      expect(
        () async => await CunningDocumentScanner.getPictures(),
        throwsA(isA<CunningDocumentScannerException>()
            .having((e) => e.code, 'code', 'permission_denied')
            .having(
                (e) => e.message, 'message', 'Camera permission not granted')),
      );
    });
  });

  group('CunningDocumentScanner Plugin exceptions', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      PermissionHandlerPlatform.instance = MockPermissionHandlerPlatform();
    });

    test('getPictures with MissingPluginException', () async {
      expect(() async => await CunningDocumentScanner.getPictures(),
          throwsA(isA<MissingPluginException>()));
    });
  });

  group('CunningDocumentScanner granted permission', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      PermissionHandlerPlatform.instance = MockPermissionHandlerPlatform();
    });

    void loadPlatformChannel(WidgetTester tester, List<String> result) {
      MethodChannel channel = const MethodChannel('cunning_document_scanner');

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) => Future.value(result),
      );
    }

    testWidgets('getPictures empty result', (WidgetTester tester) async {
      final List<String> emptyResult = [];
      loadPlatformChannel(tester, emptyResult);
      final result = await CunningDocumentScanner.getPictures();
      expect(result, emptyResult);
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
      MethodChannel channel = const MethodChannel('cunning_document_scanner');

      var passedAsPdf = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) {
          passedAsPdf = methodCall.arguments['asPdf'] ?? false;
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
      MethodChannel channel = const MethodChannel('cunning_document_scanner');

      String? passedSource;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) {
          passedSource = methodCall.arguments['scannerSource'];
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
      MethodChannel channel = const MethodChannel('cunning_document_scanner');

      String? passedSource;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (MethodCall methodCall) {
          passedSource = methodCall.arguments['scannerSource'];
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
      MethodChannel channel = const MethodChannel('cunning_document_scanner');

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
  });
}
