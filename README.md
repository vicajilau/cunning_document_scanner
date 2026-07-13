# Cunning Document Scanner

### In Loving Memory of Marcel Pater 🌟

> *“A new star has lit up in the sky... one that will shine brightly and guide us forever.”*
>
> This repository is dedicated to the memory of its creator and owner, **Marcel Pater**.
> Thank you, Marcel, for your passion, your dedication, and for sharing your light with the world. You will always be remembered.
>
> His work lives on, and this project continues to be maintained in his honor.

---

Cunning Document Scanner is a Flutter-based document scanner application that enables you to capture images of paper documents and convert them into digital files effortlessly. This application is designed to run on Android and iOS devices with minimum API levels of 21 and 13, respectively.

## Key Features

- Fast and easy document scanning.
- Conversion of document images into digital files.
- Support for both Android and iOS platforms.
- Minimum requirements: API 21 on Android, iOS 13 on iOS.
- Limit the number of scannable files on Android.
- Allows selection of images from the gallery on Android.

A state of the art document scanner with automatic cropping function.

<img src="https://user-images.githubusercontent.com/1488063/167291601-c64db2d5-78ab-4781-bc7a-afe7eb93e083.png" height ="400"  alt=""/>
<img src="https://user-images.githubusercontent.com/1488063/167291821-3b66d0bb-b636-4911-a572-d2368dc95012.jpeg" height ="400"  alt=""/>
<img src="https://user-images.githubusercontent.com/1488063/167291827-fa0ae804-1b81-4ef4-8607-3b212c3ab1c0.jpeg" height ="400"  alt=""/>

## Project Setup
Follow the steps below to set up your Flutter project on Android and iOS.

### **Android**

#### Minimum Version Configuration
Ensure you meet the minimum version requirements to run the application on Android devices.
In `android/app/build.gradle`, verify that `minSdkVersion` (or `minSdk`) is at least **21**:

```gradle
android {
    ...
    defaultConfig {
        ...
        minSdkVersion 21
        ...
    }
}
```

### **iOS**

#### Minimum Version Configuration
Ensure you meet the minimum version requirements to run the application on iOS devices:
* Set the **iOS Deployment Target** in Xcode (under Minimum Deployments) to at least **13.0**.
* If your project still uses CocoaPods, make sure the platform version is at least **13.0** in your `ios/Podfile`:

  ```ruby
  platform :ios, '13.0'
  ```

#### Permission Configuration
Add the [NSCameraUsageDescription](https://developer.apple.com/documentation/bundleresources/information_property_list/nscamerausagedescription) key to your app's `ios/Runner/Info.plist` file with a description of why your app needs camera access:

```xml
<key>NSCameraUsageDescription</key>
<string>Access to the camera is required to scan documents.</string>
```

> [!NOTE]
> Since this plugin has migrated to Swift Package Manager (SPM), and the `permission_handler` dependency (version 12.0.2+) also supports SPM, permissions are now resolved automatically. The dependency scans your app's `Info.plist` and compiles only the code for the permission keys you have declared (e.g., `NSCameraUsageDescription`). You do not need to manually configure preprocessor macros in your `Podfile`.

#### Localization Configuration
To ensure native iOS UI components (like the document camera, photo library picker, and our source selection menu) are displayed in the user's preferred language (e.g., Spanish), you can enable mixed localizations in your app's `ios/Runner/Info.plist`:

```xml
<key>CFBundleAllowMixedLocalizations</key>
<true/>
```

Alternatively, you can add the supported languages to the **Localizations** list in Xcode:
1. Open `ios/Runner.xcworkspace` in Xcode.
2. Select the `Runner` project in the left project navigator.
3. In the **Info** tab, under the **Localizations** section, click the `+` button and add the languages your app supports.

If one of these configurations is applied, iOS will automatically load the plugin's built-in translations (supporting 29 major languages) and translate the system document camera UI to the device's system language. Otherwise, iOS will default all system and plugin UI strings to English.

## How to use ?

The easiest way to get a list of images is:

```dart
   final imagesPath = await CunningDocumentScanner.getPictures();
```

### PDF Export (Cross-Platform)

You can also scan directly to a single PDF document. If `asPdf` is set to `true`, the method returns a list containing a single file path pointing to the generated PDF:

```dart
   final pdfPath = await CunningDocumentScanner.getPictures(
      asPdf: true,
   );
   // pdfPath will be something like: ['/path/to/document.pdf']
```

### Scanner Source (Cross-Platform)

Configure where images are acquired from using the `scannerSource` parameter:

* **Camera only (Default)**: Opens the camera directly.
* **Gallery only**: Opens the system photo gallery directly.
* **Camera and Gallery**: Opens a selection menu (iOS) or shows a gallery shortcut (Android) letting the user choose.

```dart
   final imagesPath = await CunningDocumentScanner.getPictures(
      scannerSource: ScannerSource.cameraAndGallery,
   );
```

### Android Specific

There are some features in Android that allow you to adjust the scanner that will be ignored in iOS:

```dart
   final imagesPath = await CunningDocumentScanner.getPictures(
      noOfPages: 1, // Limit the number of pages to 1
      androidScannerMode: AndroidScannerMode.base, // Use ML Kit base mode on Android (Optional)
   );
```



### iOS Specific

On iOS it is possible to configure which image format should be used to save of the document scans. Available options are PNG (default) or JPEG. In certain situations the JPEG format could drastically reduce the file size of the final scan. If you choose to use JPEG you can also specify a compression quality, where 0.0 is highest compression (lowest quality) and 1.0 (default) is the lowest compression (highest quality). Example usage is:

Note: VisionKit does not expose a scanner mode or filter toggle on iOS. To disable filters or use only crop/rotation, a custom capture and cropping UI would be required.

```dart
   // Returns images in JPEG format with a compression quality of 50%. 
   final imagesPath = await CunningDocumentScanner.getPictures(
      iosScannerOptions: IosScannerOptions(
         imageFormat: IosImageFormat.jpg,
         jpgCompressionQuality: 0.5,
      ),
   );
```

## Installation

Add `cunning_document_scanner` as a dependency in your `pubspec.yaml` file:

```yaml
dependencies:
  cunning_document_scanner: ^2.2.0
```

Or run:

```bash
flutter pub add cunning_document_scanner
```

---

## Local Development / Example Setup

If you want to contribute to this plugin or run the example app locally:

1. Clone this repository:

   ```bash
   git clone https://github.com/jachzen/cunning_document_scanner.git
   ```

2. Navigate to the example directory:

   ```bash
   cd cunning_document_scanner/example
   ```

3. Install dependencies:

   ```bash
   flutter pub get
   ```

4. Run the application:

   ```bash
   flutter run
   ```

## Contributions

Contributions are welcome. If you want to contribute to the development of Cunning Document Scanner, follow these steps:

1. Fork the repository.
2. Create a branch for your contribution: `git checkout -b your_feature`
3. Make your changes and commit: `git commit -m 'Add a new feature'`
4. Push the branch: `git push origin your_feature`
5. Open a pull request on GitHub.

## Issues and Support

If you encounter any issues or have questions, please open an [issue](https://github.com/jachzen/cunning_document_scanner/issues). We're here to help.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for more details.