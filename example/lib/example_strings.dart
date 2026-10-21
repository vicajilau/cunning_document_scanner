import 'package:flutter/widgets.dart';

/// The languages the example app is translated into.
///
/// Keep this in sync with `CFBundleLocalizations` in `ios/Runner/Info.plist`, so that iOS offers
/// the same languages in the app's Settings page and Apple's scanner screens resolve to them too.
const supportedLanguageCodes = ['en', 'es', 'ru'];

/// The example app's UI strings, resolved from the locale Flutter picked for the app.
class ExampleStrings {
  ExampleStrings._(this._strings);

  final Map<String, String> _strings;

  static ExampleStrings of(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return ExampleStrings._(
        _translations[languageCode] ?? _translations['en']!);
  }

  String get appTitle => _strings['appTitle']!;
  String get scanAsPdf => _strings['scanAsPdf']!;
  String get scanAsPdfSubtitle => _strings['scanAsPdfSubtitle']!;
  String get maxPages => _strings['maxPages']!;
  String get maxPagesHint => _strings['maxPagesHint']!;
  String get invalidNumber => _strings['invalidNumber']!;
  String get pagesMin => _strings['pagesMin']!;
  String get useScannerSource => _strings['useScannerSource']!;
  String get useScannerSourceSubtitle => _strings['useScannerSourceSubtitle']!;
  String get scannerSource => _strings['scannerSource']!;
  String get cameraOnly => _strings['cameraOnly']!;
  String get galleryOnly => _strings['galleryOnly']!;
  String get cameraAndGallery => _strings['cameraAndGallery']!;
  String get allowGalleryImport => _strings['allowGalleryImport']!;
  String get allowGalleryImportSubtitle =>
      _strings['allowGalleryImportSubtitle']!;
  String get androidMode => _strings['androidMode']!;
  String get androidFull => _strings['androidFull']!;
  String get androidBase => _strings['androidBase']!;
  String get androidBaseWithFilter => _strings['androidBaseWithFilter']!;
  String get iosFilter => _strings['iosFilter']!;
  String get showFilterBar => _strings['showFilterBar']!;
  String get showFilterBarSubtitle => _strings['showFilterBarSubtitle']!;
  String get addPictures => _strings['addPictures']!;
  String get tapToOpenPdf => _strings['tapToOpenPdf']!;
  String invalidParameter(Object? message) =>
      _strings['invalidParameter']!.replaceAll('{message}', '$message');
  String scannerError(Object? message) =>
      _strings['scannerError']!.replaceAll('{message}', '$message');
  String error(Object? message) =>
      _strings['error']!.replaceAll('{message}', '$message');

  static const _translations = <String, Map<String, String>>{
    'en': {
      'appTitle': 'Plugin example app',
      'scanAsPdf': 'Scan as PDF',
      'scanAsPdfSubtitle': 'Compile pages into a single PDF document',
      'maxPages': 'Max Number of Pages (noOfPages)',
      'maxPagesHint': 'Minimum 1',
      'invalidNumber': 'Please enter a valid number (min 1)',
      'pagesMin': 'Number of pages must be at least 1',
      'useScannerSource': 'Use ScannerSource Enum (New API)',
      'useScannerSourceSubtitle': 'Use new scannerSource configuration',
      'scannerSource': 'Scanner Source',
      'cameraOnly': 'Camera Only',
      'galleryOnly': 'Gallery Only',
      'cameraAndGallery': 'Camera & Gallery Menu',
      'allowGalleryImport': 'Allow Gallery Import (Legacy API)',
      'allowGalleryImportSubtitle': 'Import documents from photo library',
      'androidMode': 'Android Scanner Mode (Android Only)',
      'androidFull': 'Full (ML Enhancements & Filters)',
      'androidBase': 'Base (No Filters)',
      'androidBaseWithFilter': 'Base with Filter',
      'iosFilter': 'Default Cropper Filter (iOS Only)',
      'showFilterBar': 'Show filter bar (iOS Only)',
      'showFilterBarSubtitle':
          'When off, every page keeps the default filter above',
      'addPictures': 'Add Pictures',
      'tapToOpenPdf': 'Tap to open PDF',
      'invalidParameter': 'Invalid parameter: {message}',
      'scannerError': 'Scanner Error: {message}',
      'error': 'Error: {message}',
    },
    'es': {
      'appTitle': 'App de ejemplo del plugin',
      'scanAsPdf': 'Escanear como PDF',
      'scanAsPdfSubtitle': 'Unir las páginas en un único documento PDF',
      'maxPages': 'Número máximo de páginas (noOfPages)',
      'maxPagesHint': 'Mínimo 1',
      'invalidNumber': 'Introduce un número válido (mínimo 1)',
      'pagesMin': 'El número de páginas debe ser al menos 1',
      'useScannerSource': 'Usar el enum ScannerSource (API nueva)',
      'useScannerSourceSubtitle': 'Usar la nueva configuración scannerSource',
      'scannerSource': 'Origen del escáner',
      'cameraOnly': 'Solo cámara',
      'galleryOnly': 'Solo galería',
      'cameraAndGallery': 'Menú de cámara y galería',
      'allowGalleryImport': 'Permitir importar de la galería (API antigua)',
      'allowGalleryImportSubtitle': 'Importar documentos de la fototeca',
      'androidMode': 'Modo del escáner de Android (solo Android)',
      'androidFull': 'Completo (mejoras ML y filtros)',
      'androidBase': 'Básico (sin filtros)',
      'androidBaseWithFilter': 'Básico con filtro',
      'iosFilter': 'Filtro por defecto del recorte (solo iOS)',
      'showFilterBar': 'Mostrar barra de filtros (solo iOS)',
      'showFilterBarSubtitle':
          'Si está desactivada, todas las páginas usan el filtro por defecto',
      'addPictures': 'Añadir imágenes',
      'tapToOpenPdf': 'Toca para abrir el PDF',
      'invalidParameter': 'Parámetro no válido: {message}',
      'scannerError': 'Error del escáner: {message}',
      'error': 'Error: {message}',
    },
    'ru': {
      'appTitle': 'Пример использования плагина',
      'scanAsPdf': 'Сканировать в PDF',
      'scanAsPdfSubtitle': 'Объединить страницы в один PDF-документ',
      'maxPages': 'Максимум страниц (noOfPages)',
      'maxPagesHint': 'Минимум 1',
      'invalidNumber': 'Введите корректное число (минимум 1)',
      'pagesMin': 'Количество страниц должно быть не меньше 1',
      'useScannerSource': 'Использовать ScannerSource (новый API)',
      'useScannerSourceSubtitle': 'Использовать новую настройку scannerSource',
      'scannerSource': 'Источник сканирования',
      'cameraOnly': 'Только камера',
      'galleryOnly': 'Только галерея',
      'cameraAndGallery': 'Меню камеры и галереи',
      'allowGalleryImport': 'Разрешить импорт из галереи (старый API)',
      'allowGalleryImportSubtitle': 'Импорт документов из медиатеки',
      'androidMode': 'Режим сканера Android (только Android)',
      'androidFull': 'Полный (ML-улучшения и фильтры)',
      'androidBase': 'Базовый (без фильтров)',
      'androidBaseWithFilter': 'Базовый с фильтром',
      'iosFilter': 'Фильтр по умолчанию (только iOS)',
      'showFilterBar': 'Показывать панель фильтров (только iOS)',
      'showFilterBarSubtitle':
          'Если выключено, все страницы используют фильтр по умолчанию',
      'addPictures': 'Добавить изображения',
      'tapToOpenPdf': 'Нажмите, чтобы открыть PDF',
      'invalidParameter': 'Недопустимый параметр: {message}',
      'scannerError': 'Ошибка сканера: {message}',
      'error': 'Ошибка: {message}',
    },
  };
}
