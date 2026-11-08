# Removes Flutter's Swift Package Manager integration from an Xcode project, leaving it as
# an app that consumes its plugins through CocoaPods only.
#
# The example app is migrated to Swift Package Manager, and Flutter does not undo that when
# the feature is turned off: the project keeps depending on FlutterGeneratedPluginSwiftPackage,
# which no longer resolves. It also references the plugin's own package and FlutterFramework,
# so the plugin can be edited from Xcode, and Xcode resolves every package it references.
# CI runs this before building the example with CocoaPods.
#
# Usage: ruby tool/remove_spm_integration.rb example/ios/Runner.xcodeproj
require 'xcodeproj'

PACKAGE = 'FlutterGeneratedPluginSwiftPackage'.freeze

abort "usage: #{$PROGRAM_NAME} <path to .xcodeproj>" unless ARGV.length == 1
project = Xcodeproj::Project.open(ARGV[0])

project.targets.each do |target|
  target.package_product_dependencies.select { |dep| dep.product_name == PACKAGE }.each do |dep|
    target.frameworks_build_phase.files.select { |file| file.product_ref == dep }.each(&:remove_from_project)
    dep.remove_from_project
  end
end

project.root_object.package_references
       .select { |ref| ref.respond_to?(:relative_path) && ref.relative_path.to_s.end_with?(PACKAGE) }
       .each(&:remove_from_project)

# Folder references Xcode opens as local packages: the generated one, FlutterFramework,
# and any folder holding a Package.swift, such as the plugin's own.
packages = project.files.select do |file|
  next false unless file.last_known_file_type == 'wrapper'

  [PACKAGE, 'FlutterFramework'].include?(File.basename(file.path.to_s)) ||
    File.exist?(File.join(file.real_path.to_s, 'Package.swift'))
end
packages.each do |file|
  puts "Removing the reference to #{file.path}"
  file.remove_from_project
end

project.save

pbxproj = File.read(File.join(ARGV[0], 'project.pbxproj'))
leftover = [PACKAGE, 'FlutterFramework', 'XCLocalSwiftPackageReference'].select { |name| pbxproj.include?(name) }
abort "Still referenced: #{leftover.join(', ')}" unless leftover.empty?
puts "Removed the Swift Package Manager integration from #{ARGV[0]}"
