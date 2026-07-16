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
  s.source       = { :git => "https://github.com/akashskypatel/ffmpeg-kit-extended.git", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm}", "cpp/**/*.{hpp,cpp,c,h}", "ios/generated/*.{h,cpp,mm}"
  s.private_header_files = "ios/**/*.h"

  # The bridge intentionally does not link libffmpegkit at compile time.
  # The application must embed the matching FFmpegKit Extended framework;
  # symbols are resolved with dlsym(RTLD_DEFAULT, ...) at runtime.
  install_modules_dependencies(s)
end
