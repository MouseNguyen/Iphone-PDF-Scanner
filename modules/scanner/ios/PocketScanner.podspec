Pod::Spec.new do |s|
  s.name = 'PocketScanner'
  s.module_name = 'PocketScannerNative'
  s.version = '0.1.0'
  s.summary = 'Local document scanning, recognition and PDF export'
  s.description = s.summary
  s.license = { :type => 'MIT' }
  s.author = 'Duke'
  s.homepage = 'https://expo.dev'
  s.platforms = { :ios => '16.4' }
  s.source = { :git => '' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.frameworks = 'VisionKit', 'Vision', 'CoreImage', 'UIKit', 'CoreText', 'QuickLook'
  s.swift_version = '5.9'
  s.source_files = '*.swift'
  s.test_spec 'Tests' do |test|
    test.source_files = 'Tests/*.swift'
    test.frameworks = 'XCTest', 'UIKit'
  end
end
