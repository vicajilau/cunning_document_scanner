## 3.0.0

> [!IMPORTANT]
> This release changes where scanned files are written and how cancellation is reported.
> Read the breaking changes below before upgrading.

### Breaking changes
* **`permission_handler` is no longer a dependency.** The iOS camera permission is now requested natively through `AVCaptureDevice`, which is exactly the API `permission_handler` wrapped for `Permission.camera`. If your app imports `package:permission_handler` **without declaring it in your own `pubspec.yaml`** — relying on it arriving transitively through this plugin — add it explicitly:
  ```bash
  flutter pub add permission_handler
  ```
  Nothing else changes: permission refusals still throw `CunningDocumentScannerException` with `code: 'permission_denied'` and the same message. Apps that already declare `permission_handler` are unaffected.
* **iOS output moved out of the `Documents` directory.** Scans and generated PDFs are now written to a private `Library/Caches/cunning_document_scanner/` subdirectory. The returned paths are still absolute and readable, but the files are no longer backed up to iCloud and may be reclaimed by the system. Copy anything you need to keep to your own storage.
* **`getPictures()` now returns `null` on cancellation on every platform.** Android previously returned an empty list, contradicting the documented contract. Empty native results are normalized to `null`.
* **Native errors are reported as `CunningDocumentScannerException`.** `getPictures()` and `cleanCache()` no longer leak `PlatformException`; the platform error code is preserved in `CunningDocumentScannerException.code`.
* **`androidScannerMode` is no longer nullable.** It defaults to `AndroidScannerMode.full`; remove any explicit `null`.
* **`IosScannerOptions` is no longer a `const` constructor.** It now validates `jpgCompressionQuality` and throws an `ArgumentError` for values outside 0.0 - 1.0.

### Fixed
* **The scanner could be locked out for the rest of the process on iPad.** The `cameraAndGallery` action sheet is a popover there, and dismissing it by tapping outside could leave the pending result callback stranded, after which every later call failed with `ALREADY_ACTIVE`. The same happened when no view controller was available to present from. Dismissal by gesture is now treated as a cancellation, and a missing presenter fails immediately with `NO_VIEW_CONTROLLER` rather than consuming the call.
* **`cleanCache()` no longer requires an attached `Activity` on Android.** It only ever needed a `Context`, so cleaning at startup — before any `Activity` is attached — used to fail with `NO_ACTIVITY` for no technical reason.
* **A `restricted` camera authorization was ignored on iOS.** Devices under parental controls or an MDM policy report `restricted`, which the Dart-side check did not treat as a refusal, so the scanner opened a camera the user could never grant access to. The native check covers it.
* **The camera permission was requested even for gallery-only flows.** `ScannerSource.gallery` uses the out-of-process system photo picker, which needs no permission; it no longer prompts for anything.
* **`cleanCache()` could delete host application data.** On iOS it removed every `.pdf`, `.jpg` and `.png` in the app's `Documents` directory; on Android it matched by file extension in `cacheDir` and the pictures directory. Both now delete only files the plugin itself wrote, identified by the `DOCUMENT_SCAN_` prefix and the private storage directory.
* **Android gallery multi-selection was broken.** The picker requested multiple selection but only read `Intent.data`, so selecting more than one image reported "No image selected". Selections are now read from `clipData` and every image is cropped in sequence.
* **Android gallery imports ignored `noOfPages`**, hardcoding a single page.
* Concurrent `getPictures()` calls no longer orphan the first call's `Future`; the second call fails fast with an `ALREADY_ACTIVE` error.
* Calling the plugin while detached from an `Activity` returns a `NO_ACTIVITY` error instead of crashing with `UninitializedPropertyAccessException`.
* iOS image write failures are surfaced as errors instead of returning paths to files that were never created.
* Removed the leftover Huawei `com.huawei.hms.ml.DEPENDENCY` manifest entry, which was still being merged into every host application after HMS support was dropped in 2.6.0.

### Added
* `IosScannerOptions.defaultFilter` and `IosScannerOptions.showFilterBar` expose the iOS cropper filters (`IosDocumentFilter.original`, `.color`, `.grayscale`, `.blackAndWhite`) to Dart.
* Kotlin unit tests for the method channel argument helpers, run in CI.
* `tool/check_versions.sh`, run in CI, fails the build when `pubspec.yaml`, the podspec, `android/build.gradle.kts` and the changelog disagree on the version.

### Changed
* Removed the unconditional debug logging from the Android plugin and the debug `print` from the Dart layer; both leaked file paths and URIs into release logs.
* `plugin_platform_interface` moved to `dev_dependencies`; it was only ever used by tests.
* Added `topics` and `issue_tracker` to `pubspec.yaml`.
* Stricter analysis (`strict-casts`, `strict-raw-types`, `public_member_api_docs`) and raised, rather than disabled, the SwiftLint size and complexity rules.

## 2.8.0
### iOS
* Added document image filter options (**Original**, **Color**, **Grayscale**, **B&W**) to the custom document cropper (`CunningDocumentCropperViewController`) when importing images from the gallery, achieving feature parity with Android ML Kit (fixes #153).

## 2.7.0
### General
* Added `CunningDocumentScanner.cleanCache()` to clear temporary scanned images and generated PDF files from local storage.
* Enforced `noOfPages` page limit validation in Dart (`noOfPages > 0`), throwing an `ArgumentError` when invalid values are supplied.
* Documented exception handling for `ArgumentError` and `CunningDocumentScannerException` in DartDoc comments and `README.md`.

### iOS
* Added manual document cropper for gallery-imported images (`ScannerSource.gallery`), resolving the limitation where gallery images could not be manually cropped before export.
* Implemented `noOfPages` limit handling in both `PHPickerViewController` selection limit and `VNDocumentCameraViewController`.
* Implemented native `cleanCache` support.
* Implemented a circular `MagnifierView` precision zoom lens centered over handles during touch dragging, providing pixel-perfect corner positioning.
* Added a cancel confirmation dialog to prevent accidental data loss in multi-page scanning.
* Fixed rotate button behavior to properly map cropping coordinates 90 degrees clockwise without losing user progress.
* Optimized image loading and processing:
  * Offloaded heavy image orientation fixes (`fixedOrientation()`) and perspective correction filters to background threads.
  * Wrapped background processing calls in `autoreleasepool` blocks to force immediate memory deallocation and avoid OOM crashes.
  * Downscaled imported gallery images to a maximum of 2048px on load to prevent concurrent memory spikes.
  * Replaced CPU-intensive rotation with instant metadata orientation changes.
* Added translations for the new cropper discard options across all 29 localized languages.

### Android
* Implemented native `cleanCache` support purging `DOCUMENT_SCAN_` files from `cacheDir` and `PICTURES` directory.

## 2.6.0
### Android
* Removed HMS (Huawei Mobile Services) support entirely to ensure 16 KB page-size compatibility on Android 15+ (fixes #146).
* Replaced deprecated `getParcelable(key)` with type-safe `androidx.core.os.BundleCompat.getParcelable` for Android 13+ compatibility.
* Migrated the legacy `android` block to the modern `configure<LibraryExtension>` block and updated conditional Kotlin plugin application in `build.gradle.kts` to resolve build/deprecation warnings.
* Removed redundant and deprecated `sourceSets` block, as Kotlin source directories are resolved automatically by Gradle.

## 2.5.0
### General
* Introduced `ScannerSource` enum to specify the source of document images: `camera`, `gallery`, or `cameraAndGallery`.
* Deprecated `isGalleryImportAllowed` in favor of `scannerSource`. If `scannerSource` is provided, it takes precedence and `isGalleryImportAllowed` is ignored.

### Android
* Added automatic document edge detection for Huawei Mobile Services (HMS) devices using HMS ML Kit Document Skew Correction.
* Fixed a crash/restart loop issue on older GMS+HMS dual-service devices (such as Honor 8X and Huawei P30 Lite) by bypassing GMS and launching the fallback scanner directly on HMS-enabled devices.
* Added direct gallery selection support. When `ScannerSource.gallery` is chosen, the system launches the device's image picker and routes the selected image directly to the fallback crop editor (`DocumentScannerActivity`) for edge adjustment and perspective correction.

### iOS
* Integrated direct gallery picker navigation. When `ScannerSource.gallery` is chosen, the plugin opens the native photo library (`PHPickerViewController`) directly, bypassing the alert/choice menu.

## 2.4.0
### General
* Added cross-platform support for native PDF export. Call `CunningDocumentScanner.getPictures(asPdf: true)` to return a list containing a single path pointing to the generated PDF.

### Android
* Removed redundant camera and storage permissions from `AndroidManifest.xml`.
* Android no longer prompts the user for camera or storage permissions at runtime since ML Kit and the fallback camera intent handle them without requiring permission in the host app.
* Integrated native PDF support in both the Google Play Services ML Kit Document Scanner and the local low-RAM fallback scanner (using built-in `PdfDocument`).
* Migrated to "Built-in Kotlin" support, removing manual Kotlin Gradle Plugin (KGP) application for future Flutter compatibility.
* Updated Gradle wrapper to `8.14.5`.
* Updated Android Gradle Plugin (AGP) to `8.13.1`.
* Updated Kotlin version to `2.2.21`.

### iOS
* Camera permission request remains active and required for iOS VisionKit.
* Integrated native PDF compilation using `PDFKit` (converting VisionKit scan pages into a single PDF document).
* Added native support for `isGalleryImportAllowed` on iOS. Users can now choose to scan using the camera (VisionKit) or import existing documents from their photo library (`PHPickerViewController` on iOS 14+ supporting multi-selection, and `UIImagePickerController` on iOS 13). Imported images undergo the same native PDF/image conversion pipeline.
* Added native localization support supporting 29 major languages for the iOS source selection Action Sheet and VisionKit interface. Included explicit color themes using KVC to guarantee text visibility across custom dark/light themes.

## 2.3.0
### Android
* Upgraded Gradle wrapper to version `8.14.5`.
* Modernized Kotlin configuration to use the new `compilerOptions` DSL instead of legacy `kotlinOptions`.
* Cleaned up legacy build script configurations, removing deprecated dependencies (`kotlin-stdlib-jdk7`) and applying standard Kotlin DSL configurations.

## 2.2.0
### Android
* Added support for configuring the ML Kit document scanner mode.
* Added `AndroidScannerMode` enum (`full`, `base`, `baseWithFilter`) to choose between different scanning pipelines.

## 2.1.0

### General
* Bumped Dart SDK constraint to `>=3.5.0 <4.0.0`.
* Bumped Flutter SDK constraint to `>=3.24.0`.
* Upgraded `permission_handler` to `^12.0.3`.
* Upgraded `flutter_lints` constraint to `^6.0.0`.
* Moved `permission_handler_platform_interface` to `dev_dependencies`.
* Modernized Flutter code syntax.
* Added launch configurations for VS Code.

### iOS
* Migrated the iOS plugin to Swift Package Manager (SPM) for modern Flutter integration.
* Reorganized the iOS directory structure under `ios/cunning_document_scanner/` and added `Package.swift`.
* Renamed `SwiftCunningDocumentScannerPlugin` to `CunningDocumentScannerPlugin`.

## 2.0.0
### Breaking Changes
* Reorganized library structure: all implementation files moved to `lib/src/` directory.
* Renamed `ios_options.dart` to `ios_scanner_options.dart` for better clarity.
* Separated `IosImageFormat` enum into its own file (`ios_image_format.dart`).

### Improvements
* Added custom exception `CunningDocumentScannerException` with specific error codes.
* Replaced generic `Exception` with `CunningDocumentScannerException.permissionDenied()` for better error handling.
* Improved code organization with barrel exports - users only need a single import.
* Added comprehensive unit tests for custom exceptions.
* Enhanced equality operators for `CunningDocumentScannerException`.

### Migration Guide
* No changes required for users - the public API remains the same with `import 'package:cunning_document_scanner/cunning_document_scanner.dart';`
* If catching exceptions, update catch blocks to use `CunningDocumentScannerException` instead of generic `Exception`.

## 1.4.0
### General
* Bumped `permission_handler` to `12.0.1`.
* Updated the example app to use Kotlin `2.2.21`, Android Gradle Plugin `8.13.1`, and Gradle `8.13`.
* Added detailed documentation comments to the `CunningDocumentScanner` class.
### Android
* Upgraded `play-services-mlkit-document-scanner` to `16.0.0`.
* Updated `compileSdk` to `34`.

## 1.3.1
* Upgraded dependencies.

## 1.3.0
* Allow users to configure the image output type on iOS (PNG or JPEG).

## 1.2.3
* Fix iOS crash where Documentscanner is not available

## 1.2.2
* Fix bitmap exception crash on Android (thanks to rosenberg_ptr)

## 1.2.1
* Add fallback for Android devices < 1.7GB RAM

## 1.2.0
* Use ML kit on Android
* dropped nocrop support
* image quality dropped

## 1.1.5
* Nmed parameters
* crop default is false
* dependencies updated
* min ios version 12 now

## 1.1.4
* Fixed iOS permission issue in example
* upgraded permission_handler

## 1.1.3
* Fixed permanently denied permission issue
* Merged crop option for android - Thanks Edwin

## 1.1.2
* iOS return unique filenames

## 1.1.1
* Updated android documentscanner library

## 1.1.0
* Exchanged android documentscanner with https://github.com/WebsiteBeaver/android-document-scanner

## 1.0.4
* Fixed conflicting requestcodes issue

## 1.0.3
* Updated permission handler constraint to ^10
* Android fixed nullsafe access issues

## 1.0.2
* Cleanup code - added images to README.md

## 1.0.1

* Fixed Playstore issue exported activity. Added documentation.

## 1.0.0

* Android and iOs Documentscanner based on Visionkit and AndroidDocument https://github.com/mayuce/AndroidDocumentScanner
