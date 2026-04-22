#
# FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
# Copyright (C) 2026 Akash Patel
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
#

Pod::Spec.new do |s|
  s.name             = 'ffmpeg_kit_extended_flutter'
  s.version          = '0.4.0'
  s.summary          = 'FFmpeg Kit Extended for Flutter'
  s.description      = 'A Flutter plugin for running FFmpeg, FFprobe, and FFplay commands with iOS support.'
  s.homepage         = 'https://github.com/akashskypatel/ffmpeg-kit-extended'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'akashskypatel' => 'akashskypatel@gmail.com' }

  s.ios.deployment_target = '13.0'
  s.requires_arc = true
  s.static_framework = true

  s.source = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  s.dependency 'Flutter'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }

  # Frameworks required by FFmpeg
  s.ios.frameworks = ['AVFoundation', 'CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
  s.libraries = ['c++', 'iconv', 'z']

  # Locate XCFramework from current_path.txt (written by configure.dart)
  xcframework_path = nil
  real_dir = File.realpath(__dir__)
  puts "FFmpegKit: real_dir -> #{real_dir}"
  project_root = File.expand_path('..', real_dir)
  puts "FFmpegKit: project_root -> #{project_root}"
  current_path_file = File.join(project_root, '.dart_tool', 'ffmpeg_kit_extended_flutter', 'ios', 'current_path.txt')
  puts "FFmpegKit: current_path_file -> #{current_path_file}"

  if File.exist?(current_path_file)
    xcframework_path = File.read(current_path_file).strip
    puts "FFmpegKit: current_path.txt -> #{xcframework_path}"
  end

  # Fallback: old prebuilt path
  if !xcframework_path || !Dir.exist?(xcframework_path)
    fallback_path = File.expand_path('../../prebuilt/apple/xcframeworks/bundle-base-ios-universal-lgpl.xcframework', __dir__)
    puts "FFmpegKit: fallback_path -> #{fallback_path}"
    if Dir.exist?(fallback_path)
      puts "FFmpegKit: Using fallback XCFramework at #{fallback_path}"
      xcframework_path = fallback_path
    end
  end

  if !xcframework_path || !Dir.exist?(xcframework_path)
    puts "FFmpegKit: WARNING - XCFramework not found. Run 'dart run ffmpeg_kit_extended_flutter:configure ios' to download."
  end

  # Extract the iOS slice from the per-platform XCFramework
  if xcframework_path && Dir.exist?(xcframework_path)
    ios_slice = if Dir.glob("#{xcframework_path}/*.dylib").any?
      xcframework_path
    else
      Dir.glob("#{xcframework_path}/ios-*").first
    end

    if ios_slice && Dir.exist?(ios_slice)
      puts "FFmpegKit: iOS slice: #{ios_slice}"

      frameworks_dir = File.join(real_dir, 'Frameworks')
      FileUtils.rm_rf(frameworks_dir)
      FileUtils.mkdir_p(frameworks_dir)

      dylib_count = 0
      Dir.glob("#{ios_slice}/*.dylib").each do |dylib|
        dylib_name = File.basename(dylib)
        dest = File.join(frameworks_dir, dylib_name)
        FileUtils.cp(dylib, dest)
        puts "FFmpegKit: Copied #{dylib_name}"
        dylib_count += 1
      end

      if dylib_count > 0
        puts "FFmpegKit: Vendoring #{dylib_count} dylib(s)"
        s.pod_target_xcconfig = {
          'DEFINES_MODULE' => 'YES',
          'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
          'LIBRARY_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Frameworks"',
          'OTHER_LDFLAGS' => '-lffmpegkit',
          'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @loader_path/Frameworks @executable_path/../Frameworks'
        }

        copy_script = <<~SCRIPT
          set -e
          TARGET_DIR="${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.framework/Versions/A/Frameworks"
          mkdir -p "$TARGET_DIR"
          cp -Rf "${PODS_TARGET_SRCROOT}/Frameworks"/*.dylib "$TARGET_DIR/" 2>/dev/null || true
          cp -Rf "${PODS_TARGET_SRCROOT}/Frameworks"/*.framework "$TARGET_DIR/" 2>/dev/null || true
        SCRIPT
        s.script_phase = {
          :name => 'Embed FFmpegKit dylibs',
          :script => copy_script,
          :execution_position => :after_compile
        }
      else
        puts "FFmpegKit: ERROR - No dylibs found in #{ios_slice}"
      end
    else
      puts "FFmpegKit: ERROR - iOS slice not found at #{xcframework_path}/ios-*"
      puts "FFmpegKit: Available slices:"
      Dir.glob("#{xcframework_path}/*").each { |d| puts "  - #{File.basename(d)}" }
    end
  end
end
