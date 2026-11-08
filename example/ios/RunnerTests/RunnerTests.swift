import UIKit
import XCTest

@testable import cunning_document_scanner

/// Tests for the parts of the plugin that run without a camera or a user: argument parsing,
/// the page limit, image downscaling and how the plugin's resources are packaged.
final class CunningScannerOptionsTests: XCTestCase {

    func testDefaultsWithoutArguments() {
        let options = CunningScannerOptions.fromArguments(args: nil)

        XCTAssertEqual(options.imageFormat, .png)
        XCTAssertEqual(options.jpgCompressionQuality, 1.0)
        XCTAssertEqual(options.output, .images)
        XCTAssertEqual(options.scannerSource, .camera)
        XCTAssertEqual(options.noOfPages, 100)
        XCTAssertEqual(options.defaultFilter, .original)
        XCTAssertTrue(options.showFilterBar)
    }

    func testDefaultsForArgumentsOfTheWrongShape() {
        let options = CunningScannerOptions.fromArguments(args: ["output", "pdf"])

        XCTAssertEqual(options.output, .images)
        XCTAssertEqual(options.noOfPages, 100)
    }

    func testParsesEveryArgument() {
        let options = CunningScannerOptions.fromArguments(args: [
            "noOfPages": 3,
            "scannerSource": "camera_and_gallery",
            "output": "images_and_pdf",
            "androidScannerMode": "full",
            "iosScannerOptions": [
                "imageFormat": "jpg",
                "jpgCompressionQuality": 0.5,
                "defaultFilter": "blackAndWhite",
                "showFilterBar": false
            ] as [String: Any]
        ])

        XCTAssertEqual(options.imageFormat, .jpg)
        XCTAssertEqual(options.jpgCompressionQuality, 0.5)
        XCTAssertEqual(options.output, .imagesAndPdf)
        XCTAssertEqual(options.scannerSource, .cameraAndGallery)
        XCTAssertEqual(options.noOfPages, 3)
        XCTAssertEqual(options.defaultFilter, .blackAndWhite)
        XCTAssertFalse(options.showFilterBar)
    }

    func testFallsBackOnUnknownValues() {
        let options = CunningScannerOptions.fromArguments(args: [
            "scannerSource": "scanner",
            "output": "tiff",
            "iosScannerOptions": [
                "imageFormat": "heic",
                "defaultFilter": "sepia"
            ]
        ])

        XCTAssertEqual(options.scannerSource, .camera)
        XCTAssertEqual(options.output, .images)
        XCTAssertEqual(options.imageFormat, .png)
        XCTAssertEqual(options.defaultFilter, .original)
    }

    func testOutputSelectsTheFilesToProduce() {
        XCTAssertTrue(CunningScanOutput.images.wantsImages)
        XCTAssertFalse(CunningScanOutput.images.wantsPdf)
        XCTAssertFalse(CunningScanOutput.pdf.wantsImages)
        XCTAssertTrue(CunningScanOutput.pdf.wantsPdf)
        XCTAssertTrue(CunningScanOutput.imagesAndPdf.wantsImages)
        XCTAssertTrue(CunningScanOutput.imagesAndPdf.wantsPdf)
    }

    func testDocumentFilterRoundTripsItsChannelValue() {
        for filter in DocumentFilter.allCases {
            XCTAssertEqual(DocumentFilter(methodChannelValue: filter.methodChannelValue), filter)
        }
    }
}

final class PageLimitTests: XCTestCase {

    private func options(noOfPages: Int) -> CunningScannerOptions {
        CunningScannerOptions(
            imageFormat: .png,
            jpgCompressionQuality: 1.0,
            output: .images,
            scannerSource: .camera,
            noOfPages: noOfPages
        )
    }

    func testKeepsEveryPageUnderTheLimit() {
        let split = options(noOfPages: 5).pageSplit(forScanned: 3)
        XCTAssertEqual(split.kept, 3)
        XCTAssertEqual(split.discarded, 0)
    }

    func testKeepsEveryPageAtTheLimit() {
        let split = options(noOfPages: 3).pageSplit(forScanned: 3)
        XCTAssertEqual(split.kept, 3)
        XCTAssertEqual(split.discarded, 0)
    }

    func testDiscardsThePagesOverTheLimit() {
        let split = options(noOfPages: 2).pageSplit(forScanned: 7)
        XCTAssertEqual(split.kept, 2)
        XCTAssertEqual(split.discarded, 5)
    }

    func testNeverReturnsANegativeCount() {
        let split = options(noOfPages: -1).pageSplit(forScanned: -4)
        XCTAssertEqual(split.kept, 0)
        XCTAssertEqual(split.discarded, 0)
    }
}

final class DownscaleTests: XCTestCase {

    private func image(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            .image { context in
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
    }

    func testLeavesASmallImageUntouched() {
        let small = image(width: 800, height: 600)
        XCTAssertTrue(small.downscaled(toMaxDimension: 2048) === small)
    }

    func testShrinksTheLongestSideKeepingTheAspectRatio() {
        let downscaled = image(width: 4096, height: 1024).downscaled(toMaxDimension: 2048)

        XCTAssertEqual(downscaled.size.width, 2048)
        XCTAssertEqual(downscaled.size.height, 512)
        XCTAssertEqual(downscaled.scale, 1.0)
    }
}

final class ResourcePackagingTests: XCTestCase {

    private let languages = [
        "ar", "ca", "cs", "da", "de", "el", "en", "es", "eu", "fi", "fr", "gl", "he", "hi", "id",
        "it", "ja", "ko", "nb", "nl", "pl", "pt", "ro", "ru", "sv", "th", "tr", "uk", "vi",
        "zh-Hans", "zh-Hant"
    ]

    private func strings(for language: String) -> [String: String]? {
        guard let path = CunningDocumentScannerPlugin.resourceBundle.path(
            forResource: "Localizable",
            ofType: "strings",
            inDirectory: nil,
            forLocalization: language
        ) else {
            return nil
        }
        return NSDictionary(contentsOfFile: path) as? [String: String]
    }

    func testShipsEveryTranslationWithTheSameKeys() throws {
        let english = try XCTUnwrap(strings(for: "en"), "en.lproj is missing")
        XCTAssertFalse(english.isEmpty)

        for language in languages {
            let translation = try XCTUnwrap(strings(for: language), "\(language).lproj is missing")
            XCTAssertEqual(Set(translation.keys), Set(english.keys), "\(language) keys differ from en")
        }
    }

    func testResolvesAPluginString() {
        let value = CunningDocumentScannerPlugin().getLocalizedOption(
            "cunning_document_scanner_camera",
            defaultValue: "<missing>"
        )
        XCTAssertNotEqual(value, "<missing>")
    }

    /// Copied loose into the app, the plugin's `Localizable.strings` would replace the host
    /// app's own file of the same name, which the plugin also reads its overrides from.
    func testKeepsItsStringsOutOfTheHostApp() {
        for language in languages {
            XCTAssertNil(
                Bundle.main.path(
                    forResource: "Localizable",
                    ofType: "strings",
                    inDirectory: nil,
                    forLocalization: language
                ),
                "the plugin's \(language) strings ended up in the host app bundle"
            )
        }
    }

    func testKeepsItsPrivacyManifestOutOfTheHostApp() {
        XCTAssertNil(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
    }
}

/// Dismissals the user starts by swiping or tapping outside, which UIKit reports only to the
/// presentation controller delegate. Each must deliver the pending result, or every later scan
/// is rejected as ALREADY_ACTIVE.
final class DismissalTests: XCTestCase {

    /// A plugin with a scan in flight, recording what its result callback receives.
    private func pluginAwaitingResult() -> (CunningDocumentScannerPlugin, () -> [Any?]) {
        let plugin = CunningDocumentScannerPlugin()
        var delivered: [Any?] = []
        plugin.resultChannel = { delivered.append($0) }
        return (plugin, { delivered })
    }

    func testThePhotoPickerReportsItsDismissalToThePlugin() throws {
        let plugin = CunningDocumentScannerPlugin()
        let picker = plugin.makeGalleryPicker()

        let delegate = try XCTUnwrap(picker.presentationController?.delegate)
        XCTAssertTrue(delegate === plugin)
    }

    /// The case from issue #183: Gallery chosen from the Camera & Gallery sheet on iPhone,
    /// then the picker swiped away.
    func testSwipingThePhotoPickerAwayCancelsTheScan() throws {
        let (plugin, delivered) = pluginAwaitingResult()
        plugin.isHandlingAlertAction = true
        let picker = plugin.makeGalleryPicker()

        plugin.presentationControllerDidDismiss(try XCTUnwrap(picker.presentationController))

        XCTAssertEqual(delivered().count, 1)
        XCTAssertNil(delivered()[0])
        XCTAssertNil(plugin.resultChannel, "a new scan could not start")
    }

    func testTheDismissalAfterChoosingAnActionIsIgnored() throws {
        let (plugin, delivered) = pluginAwaitingResult()
        plugin.isHandlingAlertAction = true
        // Stands in for the iPad popover: replacing an alert's presentation delegate traps (#178).
        let sheet = UIViewController()

        plugin.presentationControllerDidDismiss(try XCTUnwrap(sheet.presentationController))

        XCTAssertTrue(delivered().isEmpty)
        XCTAssertNotNil(plugin.resultChannel)
        XCTAssertFalse(plugin.isHandlingAlertAction)
    }

    func testTappingOutsideThePopoverCancelsTheScan() throws {
        let (plugin, delivered) = pluginAwaitingResult()
        // Stands in for the iPad popover: replacing an alert's presentation delegate traps (#178).
        let sheet = UIViewController()

        plugin.presentationControllerDidDismiss(try XCTUnwrap(sheet.presentationController))

        XCTAssertEqual(delivered().count, 1)
        XCTAssertNil(plugin.resultChannel)
    }

    func testAResultIsDeliveredOnlyOnce() throws {
        let (plugin, delivered) = pluginAwaitingResult()
        let picker = plugin.makeGalleryPicker()
        let presentation = try XCTUnwrap(picker.presentationController)

        plugin.presentationControllerDidDismiss(presentation)
        plugin.presentationControllerDidDismiss(presentation)

        XCTAssertEqual(delivered().count, 1)
    }
}
