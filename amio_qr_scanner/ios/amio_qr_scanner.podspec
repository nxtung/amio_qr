Pod::Spec.new do |s|
  s.name             = 'amio_qr_scanner'
  s.version          = '1.0.0'
  s.summary          = 'Native QR scanner for AMIO and DGX projects'
  s.description      = 'Native QR scanner using AVFoundation and Vision for Flutter.'
  s.homepage         = 'https://amio.vn'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'DGX' => 'tech@dgx.com.vn' }
  s.source           = { :path => '.' }

  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.swift_version = '5.0'
  s.frameworks = 'AVFoundation', 'Vision', 'UIKit', 'PhotosUI', 'CoreImage'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.resource_bundles = {'amio_qr_scanner_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end
