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

  # Frameworks required by FFmpeg
  s.ios.frameworks = ['AVFoundation', 'CoreMedia', 'CoreVideo', 'AudioToolbox', 'VideoToolbox']
  s.libraries = ['c++', 'iconv', 'z']

  # Note: The plugin does NOT link against FFmpegKit at build-time.
  # It resolves symbols at runtime via dlsym(RTLD_DEFAULT, ...).
  # libffmpegkit.dylib is bundled via hook/build.dart and CodeAssets.
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
  }
end
