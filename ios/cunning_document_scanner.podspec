#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint cunning_document_scanner.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'cunning_document_scanner'
  s.version          = '3.1.0'
  s.summary          = 'A document scanner plugin for flutter.'
  s.description      = <<-DESC
A document scanner plugin for flutter. Scan and crop automatically on iOS and Android.
                       DESC
  s.homepage         = 'https://github.com/vicajilau/cunning_document_scanner'
  s.license          = { :file => '../LICENSE' }
  s.authors          = ['Cunning GmbH', 'Victor Carreras']
  s.source           = { :path => '.' }
  s.source_files = 'cunning_document_scanner/Sources/cunning_document_scanner/**/*.swift'
  s.resources = 'cunning_document_scanner/Sources/cunning_document_scanner/Resources/**/*'
  # The privacy manifest goes in its own bundle: copied loose by `s.resources` it would land at
  # the root of the app bundle under static linkage and collide with the app's own manifest.
  s.resource_bundles = {
    'cunning_document_scanner_privacy' => ['cunning_document_scanner/Sources/cunning_document_scanner/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
