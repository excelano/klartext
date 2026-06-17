# generate_project.rb
# Emits Harness/KlartextHarness.xcodeproj for the KlartextUI test harness.
# Build-time dev tool only — not part of the toolkit or any commit. Run with:
#   ruby Harness/generate_project.rb
require 'xcodeproj'

here = File.dirname(File.expand_path(__FILE__))
proj_path = File.join(here, 'KlartextHarness.xcodeproj')
project = Xcodeproj::Project.new(proj_path)

target = project.new_target(:application, 'KlartextHarness', :ios, '17.0')

# Source files (explicit; small and stable set).
group = project.new_group('KlartextHarness', 'KlartextHarness')
Dir.glob(File.join(here, 'KlartextHarness', '*.swift')).sort.each do |swift|
  ref = group.new_file(swift)
  target.source_build_phase.add_file_reference(ref)
end

# --- Package dependencies -------------------------------------------------

# Local: the Klartext package at the repo root (the parent of Harness/).
local = project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
local.relative_path = '..'
project.root_object.package_references << local

ui_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
ui_dep.product_name = 'KlartextUI' # local product: resolved by name, no `package` ref
target.package_product_dependencies << ui_dep
ui_bf = project.new(Xcodeproj::Project::Object::PBXBuildFile)
ui_bf.product_ref = ui_dep
target.frameworks_build_phase.files << ui_bf

# Remote: SwiftMail, pinned to the exact revision Zirbe builds against (keeps the
# NIO dependency graph on known-good commits).
remote = project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
remote.repositoryURL = 'https://github.com/Cocoanetics/SwiftMail'
remote.requirement = { 'kind' => 'revision',
                       'revision' => '3bfb4a3a2a9677c6090221f622c537870ee78960' }
project.root_object.package_references << remote

sm_dep = project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
sm_dep.package = remote
sm_dep.product_name = 'SwiftMail'
target.package_product_dependencies << sm_dep
sm_bf = project.new(Xcodeproj::Project::Object::PBXBuildFile)
sm_bf.product_ref = sm_dep
target.frameworks_build_phase.files << sm_bf

# --- Build settings -------------------------------------------------------

target.build_configurations.each do |config|
  s = config.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.excelano.KlartextHarness'
  s['PRODUCT_NAME'] = '$(TARGET_NAME)'
  s['GENERATE_INFOPLIST_FILE'] = 'YES'
  s['INFOPLIST_KEY_UILaunchScreen_Generation'] = 'YES'
  s['INFOPLIST_KEY_UIApplicationSceneManifest_Generation'] = 'YES'
  s['SWIFT_VERSION'] = '5.0'
  s['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  s['TARGETED_DEVICE_FAMILY'] = '1'
  s['SDKROOT'] = 'iphoneos'
  s['MARKETING_VERSION'] = '0.1'
  s['CURRENT_PROJECT_VERSION'] = '1'
  # Simulator CLI builds: no signing.
  s['CODE_SIGNING_ALLOWED'] = 'NO'
  s['CODE_SIGNING_REQUIRED'] = 'NO'
  s['CODE_SIGN_IDENTITY'] = ''
end

project.save

# Shared scheme so `xcodebuild -scheme KlartextHarness -destination …` works.
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.set_launch_target(target)
scheme.save_as(proj_path, 'KlartextHarness', true)

puts "Wrote #{proj_path}"
