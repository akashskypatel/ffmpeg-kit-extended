require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "FFmpegKitExtended"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => min_ios_version_supported }
  s.requires_arc = true

  s.source = {
    :git => "https://github.com/akashskypatel/ffmpeg-kit-extended.git",
    :tag => "#{s.version}"
  }

  s.source_files = \
    "ios/**/*.{h,m,mm}",
    "cpp/**/*.{hpp,cpp,c,h}",
    "ios/generated/*.{h,cpp,mm}"

  s.private_header_files = "ios/**/*.h"

  s.prepare_command = <<-CMD
    set -e

    ARTIFACT="bundle-base-ios-universal-small-lgpl"
    URL="https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download/v0.10.5-ios/${ARTIFACT}.xcframework.zip"

    mkdir -p vendor

    if [ ! -d "vendor/${ARTIFACT}.xcframework" ]; then
      echo "Downloading FFmpegKit Extended binary..."
      curl -fL "$URL" -o "vendor/${ARTIFACT}.xcframework.zip"

      echo "Extracting FFmpegKit Extended binary..."
      ditto \
        -x \
        -k \
        "vendor/${ARTIFACT}.xcframework.zip" \
        "vendor"

      rm -f "vendor/${ARTIFACT}.xcframework.zip"
    fi
  CMD

  s.vendored_frameworks =
    "vendor/bundle-base-ios-universal-small-lgpl.xcframework"

  s.frameworks = [
    "AVFoundation",
    "CoreMedia",
    "CoreVideo",
    "AudioToolbox",
    "VideoToolbox",
    "Accelerate",
    "QuartzCore"
  ]

  s.libraries = [
    "c++",
    "iconv",
    "z",
    "bz2"
  ]

  install_modules_dependencies(s)
end