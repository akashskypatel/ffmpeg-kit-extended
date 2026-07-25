require "json"
require "open3"
require "shellwords"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

module FFmpegKitExtendedPodspecHelpers
  module_function

  def ffmpeg_kit_extended_app_root
    explicit_root = ENV["FFMPEG_KIT_EXTENDED_APP_ROOT"]
    return File.expand_path(explicit_root) unless explicit_root.nil? || explicit_root.empty?

    installation_root = File.expand_path(Pod::Config.instance.installation_root.to_s)
    native_dir = File.basename(installation_root).downcase
    if ["ios", "macos", "appletvos", "tvos"].include?(native_dir)
      return File.dirname(installation_root)
    end

    installation_root
  end

  def resolve_ffmpeg_kit_extended_config(platform, app_root)
    resolver = File.join(__dir__, "scripts", "resolve-ffmpeg-kit-config.js")
    node_binary = ENV["NODE_BINARY"] || "node"
    stdout, stderr, status = Open3.capture3(
      node_binary,
      resolver,
      "--platform", platform,
      "--app-root", app_root
    )

    Pod::UI.puts(stderr.strip) unless stderr.strip.empty?
    raise stderr.strip unless status.success?

    JSON.parse(stdout)
  end

  def ffmpeg_kit_extended_prepare_call(platform, resolution, destination)
    override = resolution["override"]
    source_kind = override.nil? ? "remote" : override["kind"]
    source = if source_kind == "local"
      override["resolvedPath"]
    else
      resolution["url"]
    end
    artifact = resolution["artifact"] || File.basename(resolution["filename"].to_s)
    cacheable = override.nil? ? "1" : "0"
    checksum = resolution["checksum"] || {}

    [
      "prepare_xcframework",
      platform,
      source_kind,
      source,
      artifact,
      destination,
      resolution["cacheKey"],
      cacheable,
      checksum["method"].to_s,
      checksum["url"].to_s,
      checksum["releaseApiUrl"].to_s,
      checksum["assetName"].to_s
    ].map { |value| Shellwords.escape(value.to_s) }.join(" ")
  end

  def ffmpeg_kit_extended_apple_platforms
    explicit_platform = ENV["FFMPEG_KIT_EXTENDED_APPLE_PLATFORM"]
    unless explicit_platform.nil? || explicit_platform.empty?
      platforms = explicit_platform.split(",").map(&:strip).reject(&:empty?)
      normalized = platforms.map do |platform|
        case platform.downcase
        when "ios" then "ios"
        when "tvos", "appletvos" then "appletvos"
        when "osx", "macos" then "macos"
        else
          raise "Unsupported FFMPEG_KIT_EXTENDED_APPLE_PLATFORM value: #{platform}"
        end
      end
      return normalized.uniq
    end

    # Do not request CocoaPods' parsed Podfile object here. During React Native
    # autolinking, CocoaPods can evaluate this podspec while the Podfile itself
    # is still being parsed, before Config#podfile is available. Reading the
    # Podfile source directly is safe at that point and also correctly handles a
    # standard react-native-tvos project whose native directory is named `ios`
    # but declares `platform :tvos`.
    installation_root = File.expand_path(Pod::Config.instance.installation_root.to_s)
    podfile_path = File.join(installation_root, "Podfile")
    if File.file?(podfile_path)
      platforms = File.readlines(podfile_path).each_with_object([]) do |line, result|
        # Ignore full-line comments and trailing comments before matching the
        # CocoaPods platform DSL, e.g. `platform :ios, '15.1'`.
        source = line.sub(/#.*/, "")
        match = source.match(/^\s*platform\s+:([A-Za-z0-9_]+)\b/)
        next if match.nil?

        resolved = case match[1].downcase
        when "ios" then "ios"
        when "tvos" then "appletvos"
        when "osx", "macos" then "macos"
        end
        result << resolved unless resolved.nil?
      end.uniq
      return platforms unless platforms.empty?
    end

    # Fall back to the conventional React Native native-project directory name.
    case File.basename(installation_root).downcase
    when "ios"
      ["ios"]
    when "tvos", "appletvos"
      ["appletvos"]
    when "osx", "macos"
      ["macos"]
    else
      # Podspec tooling can evaluate the spec outside a consuming app. Defaulting
      # to iOS keeps lint/spec inspection usable; real consumers are resolved by
      # the Podfile or native-directory paths above.
      ["ios"]
    end
  end

  def ffmpeg_kit_extended_vendor_destination(platform)
    case platform
    when "ios" then "vendor/ffmpegkit.xcframework"
    when "appletvos" then "vendor/appletvos/ffmpegkit.xcframework"
    when "macos" then "vendor/macos/ffmpegkit.xcframework"
    else
      raise "Unsupported FFmpegKit Extended Apple platform: #{platform}"
    end
  end
end

app_root = FFmpegKitExtendedPodspecHelpers.ffmpeg_kit_extended_app_root
apple_platforms = FFmpegKitExtendedPodspecHelpers.ffmpeg_kit_extended_apple_platforms
apple_prepare_calls = apple_platforms.map do |platform|
  resolution = FFmpegKitExtendedPodspecHelpers.resolve_ffmpeg_kit_extended_config(platform, app_root)
  FFmpegKitExtendedPodspecHelpers.ffmpeg_kit_extended_prepare_call(
    platform,
    resolution,
    FFmpegKitExtendedPodspecHelpers.ffmpeg_kit_extended_vendor_destination(platform)
  )
end.join("\n    ")

Pod::Spec.new do |s|
  s.name         = "FFmpegKitExtended"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms = {
    :ios => min_ios_version_supported,
    :tvos => "15.1",
    :osx => "14.0"
  }
  s.requires_arc = true

  s.source = {
    :git => "https://github.com/akashskypatel/ffmpeg-kit-extended.git",
    :tag => "#{s.version}"
  }

  # C++ TurboModule implementation shared by iOS, Apple tvOS, and macOS.
  s.source_files = "cpp/**/*.{hpp,cpp,c,h}"

  # Ship only handwritten native sources. React Native Codegen is owned by the
  # consuming application and runs with that application's React Native toolchain.
  s.ios.source_files = "ios/**/*.{h,m,mm}"
  s.ios.private_header_files = "ios/**/*.h"

  s.tvos.source_files = "appletvos/**/*.{h,m,mm}"
  s.tvos.private_header_files = "appletvos/**/*.h"

  s.osx.source_files = "macos/**/*.{h,m,mm}"
  s.osx.private_header_files = "macos/**/*.h"

  s.prepare_command = <<-CMD
    set -e

    node_binary="${NODE_BINARY:-node}"
    downloader=#{Shellwords.escape(File.join(__dir__, "scripts", "download-ffmpeg-kit-artifact.js"))}

    normalize_macos_framework_bundle() {
      framework="$1"
      name="$(basename "$framework" .framework)"
      version_dir="$framework/Versions/A"

      if [ -f "$framework/Versions/Current/Resources/Info.plist" ] && \
         [ -e "$framework/Versions/Current/$name" ]; then
        return
      fi

      echo "Normalizing macOS framework bundle layout: $framework"

      rm -rf "$framework/_CodeSignature"
      mkdir -p "$version_dir/Resources"

      if [ -f "$framework/$name" ] && [ ! -e "$version_dir/$name" ]; then
        mv "$framework/$name" "$version_dir/$name"
      fi

      if [ -f "$framework/Info.plist" ]; then
        mv "$framework/Info.plist" "$version_dir/Resources/Info.plist"
      fi

      for source_dir in Headers Modules; do
        if [ -d "$framework/$source_dir" ] && [ ! -e "$version_dir/$source_dir" ]; then
          mv "$framework/$source_dir" "$version_dir/$source_dir"
        fi
      done

      if [ -d "$framework/Resources" ]; then
        ditto "$framework/Resources" "$version_dir/Resources"
        rm -rf "$framework/Resources"
      fi

      if [ ! -f "$version_dir/$name" ]; then
        echo "macOS framework executable was not found after normalization: $version_dir/$name" >&2
        exit 1
      fi

      if [ ! -f "$version_dir/Resources/Info.plist" ]; then
        echo "macOS framework Info.plist was not found after normalization: $version_dir/Resources/Info.plist" >&2
        exit 1
      fi

      rm -f "$framework/Versions/Current" \
            "$framework/$name" \
            "$framework/Resources" \
            "$framework/Headers" \
            "$framework/Modules"

      ln -s A "$framework/Versions/Current"
      ln -s "Versions/Current/$name" "$framework/$name"
      ln -s "Versions/Current/Resources" "$framework/Resources"

      if [ -d "$version_dir/Headers" ]; then
        ln -s "Versions/Current/Headers" "$framework/Headers"
      fi

      if [ -d "$version_dir/Modules" ]; then
        ln -s "Versions/Current/Modules" "$framework/Modules"
      fi
    }

    normalize_macos_xcframework() {
      xcframework="$1"

      find "$xcframework" -type d -name 'ffmpegkit.framework' | while IFS= read -r framework; do
        normalize_macos_framework_bundle "$framework"
      done

      if ! find "$xcframework" -type d -name 'ffmpegkit.framework' | grep -q .; then
        echo "No ffmpegkit.framework was found in macOS XCFramework: $xcframework" >&2
        exit 1
      fi
    }

    prepare_xcframework() {
      platform="$1"
      source_kind="$2"
      source="$3"
      artifact="$4"
      destination="$5"
      cache_key="$6"
      cacheable="$7"
      checksum_method="$8"
      checksum_url="$9"
      release_api_url="${10}"
      asset_name="${11}"
      marker="${destination}.ffmpeg-kit-source"
      source_key="${source_kind}:${source}"

      if [ "$cacheable" = "1" ] && [ -d "$destination" ] && [ -f "$marker" ] && \
         [ "$(cat "$marker")" = "$source_key" ]; then
        if [ "$platform" = "macos" ]; then
          normalize_macos_xcframework "$destination"
        fi
        return
      fi

      parent="$(dirname "$destination")"
      archive="${parent}/.ffmpeg-kit-${platform}-${cache_key}.zip"
      extract_root="${parent}/.ffmpeg-kit-${platform}-${cache_key}"

      mkdir -p "$parent"
      rm -rf "$destination" "$marker" "$extract_root"

      if [ "$source_kind" = "local" ] && [ -d "$source" ]; then
        echo "Using local FFmpegKit Extended ${platform} XCFramework: $source"
        ditto "$source" "$destination"
      else
        if [ "$source_kind" = "local" ]; then
          if [ ! -f "$source" ]; then
            echo "FFmpegKit Extended local override was not found: $source" >&2
            exit 1
          fi
          echo "Using local FFmpegKit Extended ${platform} archive: $source"
          cp "$source" "$archive"
        else
          echo "Preparing FFmpegKit Extended ${platform} binary: $source"
          download_args="--url $source --output $archive --retries 3 --timeout-ms 30000"
          if [ -n "$checksum_method" ]; then
            download_args="$download_args --checksum-method $checksum_method"
          fi
          if [ -n "$checksum_url" ]; then
            download_args="$download_args --checksum-url $checksum_url"
          fi
          if [ -n "$release_api_url" ]; then
            download_args="$download_args --release-api-url $release_api_url"
          fi
          if [ -n "$asset_name" ]; then
            download_args="$download_args --asset-name $asset_name"
          fi
          "$node_binary" "$downloader" $download_args
        fi

        mkdir -p "$extract_root"
        echo "Extracting FFmpegKit Extended ${platform} binary..."
        ditto -x -k "$archive" "$extract_root"
        rm -f "$archive"

        extracted="$(find "$extract_root" -type d -name '*.xcframework' -print -quit)"
        if [ -z "$extracted" ] || [ ! -d "$extracted" ]; then
          echo "Expected XCFramework was not found after extracting $artifact" >&2
          exit 1
        fi

        mv "$extracted" "$destination"
        rm -rf "$extract_root"
      fi

      printf '%s' "$source_key" > "$marker"

      if [ "$platform" = "macos" ]; then
        normalize_macos_xcframework "$destination"
      fi
    }

    #{apple_prepare_calls}
  CMD

  s.ios.vendored_frameworks = "vendor/ffmpegkit.xcframework"
  s.tvos.vendored_frameworks = "vendor/appletvos/ffmpegkit.xcframework"
  s.osx.vendored_frameworks = "vendor/macos/ffmpegkit.xcframework"

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
