#
# Be sure to run `pod lib lint PlayerExt.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'PlayerExt'
  s.version          = '0.1.0'
  s.summary          = 'A short description of PlayerExt.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/arcangel-w/PlayerExt'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'arcangel-w' => 'wuzhezmc@gmail.com' }
  s.source           = { :git => 'https://github.com/arcangel-w/PlayerExt.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.swift_version = "5.8"
  s.ios.deployment_target = '13.0'
  s.static_framework = true
  s.default_subspec = 'Core', 'AVPlayer', 'VHLivePlayer', 'TXLiteAVPlayer', 'AliPlayer'
  s.pod_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }
  s.user_target_xcconfig = { 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'arm64' }

  s.source_files = 'PlayerExt/Classes/PlayerExt.h'
  s.private_header_files = 'PlayerExt/Classes/PlayerExt.h'
  s.module_map = "PlayerExt.modulemap"

  s.subspec 'Core' do |core|
    core.source_files = 'PlayerExt/Classes/Core/**/*.swift'
    core.dependency 'ZFPlayer'
  end

  s.subspec 'AVPlayer' do |avPlayer|
    avPlayer.source_files = 'PlayerExt/Classes/AVPlayer/**/*.swift'
    avPlayer.dependency 'ZFPlayer/AVPlayer'
  end

  s.subspec 'VHLivePlayer' do |vhLivePlayer|
    vhLivePlayer.source_files = 'PlayerExt/Classes/VHLivePlayer/**/*.swift'
    vhLivePlayer.dependency 'VHLiveSDK'
  end

  s.subspec 'TXLiteAVPlayer' do |txLiteAVPlayer|
      txLiteAVPlayer.source_files = 'PlayerExt/Classes/TXLiteAVPlayer/**/*.swift'
      txLiteAVPlayer.dependency 'TXLiteAVSDK_Player'
  end

  s.subspec 'AliPlayer' do |aliPlayer|
    aliPlayer.source_files = 'PlayerExt/Classes/AliPlayer/**/*.swift'
    aliPlayer.dependency 'AliPlayerSDK_iOS'
  end

end
