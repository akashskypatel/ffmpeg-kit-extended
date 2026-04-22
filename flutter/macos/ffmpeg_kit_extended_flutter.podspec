#
# FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
# Copyright (C) 2026 Akash Patel
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
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
  s.description      = 'A Flutter plugin for running FFmpeg, FFprobe, and FFplay commands with macOS support.'
  s.homepage         = 'https://github.com/akashskypatel/ffmpeg-kit-extended'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'akashskypatel' => 'akashskypatel@gmail.com' }

  s.osx.deployment_target = '10.15'
  s.requires_arc        = true

  s.source              = { :path => '.' }
  s.source_files        = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  s.dependency          'FlutterMacOS'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES'
  }

  # Frameworks required by FFmpeg
  s.osx.frameworks = ['CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
  s.libraries = ['c++', 'iconv', 'z']

  # ===========================================================================
  # Locate XCFramework from current_path.txt (written by configure.dart)
  # ===========================================================================
  xcframework_path = nil
  real_dir = File.realpath(__dir__)
  puts "FFmpegKit: real_dir -> #{real_dir}"
  project_root = File.expand_path('..', real_dir)
  puts "FFmpegKit: project_root -> #{project_root}"
  current_path_file = File.join(project_root, '.dart_tool', 'ffmpeg_kit_extended_flutter', 'macos', 'current_path.txt')
  puts "FFmpegKit: current_path_file -> #{current_path_file}"

  if File.exist?(current_path_file)
    xcframework_path = File.read(current_path_file).strip
    puts "FFmpegKit: current_path.txt -> #{xcframework_path}"
  end

  # Fallback: old prebuilt path
  if !xcframework_path || !Dir.exist?(xcframework_path)
    fallback_path = File.expand_path('../../prebuilt/apple/xcframeworks/bundle-base-macos-universal-lgpl.xcframework', __dir__)
    puts "FFmpegKit: fallback_path -> #{fallback_path}"
    if Dir.exist?(fallback_path)
      puts "FFmpegKit: Using fallback XCFramework at #{fallback_path}"
      xcframework_path = fallback_path
    end
  end

  if !xcframework_path || !Dir.exist?(xcframework_path)
    puts "FFmpegKit: WARNING - XCFramework not found. Run 'dart run ffmpeg_kit_extended_flutter:configure macos' to download."
  end

  # ===========================================================================
  # Extract the macOS slice from the per-platform XCFramework
  # ===========================================================================
  # The per-platform XCFramework contains:
  #   - macos-arm64_x86_64  ← we need this (universal binary with all dylibs)
  #
  # vendored_frameworks doesn't work with XCFramework on macOS.
  # Instead, we extract the raw dylibs and use vendored_libraries.

  if xcframework_path && Dir.exist?(xcframework_path)
    # current_path.txt may point to the XCFramework root or directly to the macOS slice
    macos_slice = if Dir.glob("#{xcframework_path}/*.dylib").any?
      xcframework_path
    else
      Dir.glob("#{xcframework_path}/macos-*").first
    end

    if macos_slice && Dir.exist?(macos_slice)
      puts "FFmpegKit: macOS slice: #{macos_slice}"

      # Copy all dylibs to a stable location inside the plugin directory
      frameworks_dir = File.join(real_dir, 'Frameworks')
      FileUtils.rm_rf(frameworks_dir)
      FileUtils.mkdir_p(frameworks_dir)

      # Copy all dylibs from the slice
      dylib_count = 0
      Dir.glob("#{macos_slice}/*.dylib").each do |dylib|
        dylib_name = File.basename(dylib)
        dest = File.join(frameworks_dir, dylib_name)
        FileUtils.cp(dylib, dest)
        puts "FFmpegKit: Copied #{dylib_name}"
        dylib_count += 1
      end

      if dylib_count > 0
        puts "FFmpegKit: Vendoring #{dylib_count} dylib(s)"

        # Link against libffmpegkit.dylib and set rpath for runtime
        s.pod_target_xcconfig = {
          'DEFINES_MODULE' => 'YES',
          'LIBRARY_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/Frameworks"',
          'OTHER_LDFLAGS' => '-lffmpegkit',
          # Add rpath to the plugin framework's embedded Frameworks dir
          'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @loader_path/Frameworks @executable_path/../Frameworks'
        }

        # Copy dylibs into the plugin framework's Frameworks subdirectory
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
        puts "FFmpegKit: ERROR - No dylibs found in #{macos_slice}"
      end
    else
      puts "FFmpegKit: ERROR - macOS slice not found at #{xcframework_path}/macos-*"
      puts "FFmpegKit: Available slices:"
      Dir.glob("#{xcframework_path}/*").each { |d| puts "  - #{File.basename(d)}" }
    end
  end
end
