#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint cunning_document_scanner.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'cunning_document_scanner'
  s.version          = '3.0.1'
  s.summary          = 'A document scanner plugin for flutter.'
  s.description      = <<-DESC
A document scanner plugin for flutter. Scan and crop automatically on iOS and Android.
                       DESC
  s.homepage         = 'https://github.com/jachzen/cunning_document_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Cunning GmbH' => 'marcel@cunning.biz' }
  s.source           = { :path => '.' }
  s.source_files = 'cunning_document_scanner/Sources/cunning_document_scanner/**/*.swift'
  s.resources = 'cunning_document_scanner/Sources/cunning_document_scanner/Resources/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
