Pod::Spec.new do |s|
  s.name             = 'ffmpeg_kit_extended_flutter'
  s.version          = '0.4.0'
  s.summary          = 'FFmpeg Kit Extended for Flutter'
  s.description      = 'A Flutter plugin for running FFmpeg, FFprobe, and FFplay commands with iOS and macOS support.'
  s.homepage         = 'https://github.com/akashskypatel/ffmpeg-kit-extended'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'akashskypatel' => 'akashskypatel@gmail.com' }

  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.requires_arc        = true
  s.static_framework    = true

  s.source              = { :path => '.' }
  s.source_files        = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  s.script_phase = {
    :name => 'Run Configure Script',
    :script => 'cd "$PODS_TARGET_SRCROOT/.." && dart bin/configure.dart ios',
    :execution_position => :before_compile
  }

  s.default_subspec     = 'base'

  s.dependency          'Flutter'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }

  # Base LGPL variant (recommended for most users)
  s.subspec 'base' do |ss|
    ss.source_files         = 'Classes/**/*'
    ss.public_header_files  = 'Classes/**/*.h'
    ss.vendored_frameworks  = '../../prebuilt/apple/xcframeworks/ffmpegkit-base.xcframework'
    ss.ios.frameworks = ['AVFoundation', 'CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.osx.frameworks = ['CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.libraries = ['c++', 'iconv', 'z']
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
  end

  # Audio LGPL variant
  s.subspec 'audio' do |ss|
    ss.source_files         = 'Classes/**/*'
    ss.public_header_files  = 'Classes/**/*.h'
    ss.vendored_frameworks  = '../../prebuilt/apple/xcframeworks/ffmpegkit-audio.xcframework'
    ss.ios.frameworks = ['AVFoundation', 'CoreMedia', 'AudioToolbox']
    ss.osx.frameworks = ['CoreMedia', 'AudioToolbox']
    ss.libraries = ['c++', 'iconv', 'z']
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
  end

  # Video LGPL variant
  s.subspec 'video' do |ss|
    ss.source_files         = 'Classes/**/*'
    ss.public_header_files  = 'Classes/**/*.h'
    ss.vendored_frameworks  = '../../prebuilt/apple/xcframeworks/ffmpegkit-video.xcframework'
    ss.ios.frameworks = ['AVFoundation', 'CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.osx.frameworks = ['CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.libraries = ['c++', 'iconv', 'z']
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
  end

  # Video HW LGPL variant
  s.subspec 'video_hw' do |ss|
    ss.source_files         = 'Classes/**/*'
    ss.public_header_files  = 'Classes/**/*.h'
    ss.vendored_frameworks  = '../../prebuilt/apple/xcframeworks/ffmpegkit-video_hw.xcframework'
    ss.ios.frameworks = ['AVFoundation', 'CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.osx.frameworks = ['CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.libraries = ['c++', 'iconv', 'z']
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
  end

  # Full LGPL variant
  s.subspec 'full' do |ss|
    ss.source_files         = 'Classes/**/*'
    ss.public_header_files  = 'Classes/**/*.h'
    ss.vendored_frameworks  = '../../prebuilt/apple/xcframeworks/ffmpegkit-full.xcframework'
    ss.ios.frameworks = ['AVFoundation', 'CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.osx.frameworks = ['CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.libraries = ['c++', 'iconv', 'z']
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
  end

  # GPL variants (require GPL compliance)
  s.subspec 'base-gpl' do |ss|
    ss.source_files         = 'Classes/**/*'
    ss.public_header_files  = 'Classes/**/*.h'
    ss.vendored_frameworks  = '../../prebuilt/apple/xcframeworks/ffmpegkit-base-gpl.xcframework'
    ss.ios.frameworks = ['AVFoundation', 'CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.osx.frameworks = ['CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.libraries = ['c++', 'iconv', 'z']
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
  end

  s.subspec 'audio-gpl' do |ss|
    ss.source_files         = 'Classes/**/*'
    ss.public_header_files  = 'Classes/**/*.h'
    ss.vendored_frameworks  = '../../prebuilt/apple/xcframeworks/ffmpegkit-audio-gpl.xcframework'
    ss.ios.frameworks = ['AVFoundation', 'CoreMedia', 'AudioToolbox']
    ss.osx.frameworks = ['CoreMedia', 'AudioToolbox']
    ss.libraries = ['c++', 'iconv', 'z']
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
  end

  s.subspec 'video-gpl' do |ss|
    ss.source_files         = 'Classes/**/*'
    ss.public_header_files  = 'Classes/**/*.h'
    ss.vendored_frameworks  = '../../prebuilt/apple/xcframeworks/ffmpegkit-video-gpl.xcframework'
    ss.ios.frameworks = ['AVFoundation', 'CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.osx.frameworks = ['CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.libraries = ['c++', 'iconv', 'z']
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
  end

  s.subspec 'video_hw-gpl' do |ss|
    ss.source_files         = 'Classes/**/*'
    ss.public_header_files  = 'Classes/**/*.h'
    ss.vendored_frameworks  = '../../prebuilt/apple/xcframeworks/ffmpegkit-video_hw-gpl.xcframework'
    ss.ios.frameworks = ['AVFoundation', 'CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.osx.frameworks = ['CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.libraries = ['c++', 'iconv', 'z']
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
  end

  s.subspec 'full-gpl' do |ss|
    ss.source_files         = 'Classes/**/*'
    ss.public_header_files  = 'Classes/**/*.h'
    ss.vendored_frameworks  = '../../prebuilt/apple/xcframeworks/ffmpegkit-full-gpl.xcframework'
    ss.ios.frameworks = ['AVFoundation', 'CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.osx.frameworks = ['CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
    ss.libraries = ['c++', 'iconv', 'z']
    ss.ios.deployment_target = '13.0'
    ss.osx.deployment_target = '10.15'
  end

end
