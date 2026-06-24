#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint liquid_toasts.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'liquid_toasts'
  s.version          = '0.0.1'
  s.summary          = 'Native iOS toasts for Flutter with Liquid Glass and a Dynamic Island origin.'
  s.description      = <<-DESC
Liquid Toasts renders premium, SwiftUI-native toasts above your Flutter app:
adaptive Liquid Glass (with a frosted-glass fallback), a Dynamic Island origin
animation, depth stacking, loading toasts with async lifecycle, SF Symbol icons,
semantic styles, and a single rounded action button — all without a BuildContext.
                       DESC
  s.homepage         = 'https://github.com/rehmatsg/liquid-toasts'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'rehmatsg' => 'rehmat@simplify.jobs' }
  s.source           = { :path => '.' }
  s.source_files = 'liquid_toasts/Sources/liquid_toasts/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '17.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # The plugin ships a privacy manifest. It uses only public APIs and declares
  # no required-reason API usage or data collection.
  s.resource_bundles = {'liquid_toasts_privacy' => ['liquid_toasts/Sources/liquid_toasts/PrivacyInfo.xcprivacy']}
end
