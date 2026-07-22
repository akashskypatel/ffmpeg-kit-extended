#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  export JAVA_HOME="${JAVA_HOME:-/c/Program Files/Java/jdk-17}"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
example_dir="$script_dir/example"
macos_runtime_dir="$example_dir/.macos-runtime"
cd "$script_dir"

usage() {
  cat <<'USAGE'
Usage:
  ./build.sh [target] [options]

Targets:
  library     Build the React Native library only
  android     Build the library and Android example
  ios         Build the library and iOS example
  macos       Build the library and macOS example
  all         Build all supported targets for the current host

Options:
  --clean     Run ./clean before building
  --release   Build example apps in release mode
  -h, --help  Show this help
USAGE
}

target="${1:-all}"
clean_first=false
build_type="debug"

if [[ $# -gt 0 ]]; then
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean) clean_first=true ;;
    --release) build_type="release" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

case "$target" in
  library|android|ios|macos|all) ;;
  -h|--help) usage; exit 0 ;;
  *) echo "Unknown target: $target" >&2; usage; exit 1 ;;
esac

host_os="$(uname -s)"

ensure_dependencies() {
  local dir="$1"
  if [[ ! -d "$dir/node_modules" ]]; then
    echo "Installing dependencies in $dir..."
    (cd "$dir" && npm install)
  fi
}

clean_project() {
  if [[ -x "$script_dir/clean" ]]; then
    "$script_dir/clean"
  elif [[ -x "$script_dir/clean.sh" ]]; then
    "$script_dir/clean.sh"
  else
    echo "Clean script not found or not executable." >&2
    exit 1
  fi
}

ensure_apple_binary() {
  local platform="$1"
  local artifact="$2"
  local destination="$3"
  local parent archive extracted url

  if [[ -d "$destination" ]]; then
    if [[ "$platform" == "macos" ]]; then
      normalize_macos_xcframework "$destination"
    fi
    return
  fi

  parent="$(dirname "$destination")"
  archive="${parent}/${artifact}.xcframework.zip"
  extracted="${parent}/${artifact}.xcframework"
  url="https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download/v0.10.5-${platform}/${artifact}.xcframework.zip"

  mkdir -p "$parent"
  rm -rf "$extracted"

  echo "Downloading FFmpegKit Extended ${platform} binary..."
  curl -fL "$url" -o "$archive"
  echo "Extracting FFmpegKit Extended ${platform} binary..."
  ditto -x -k "$archive" "$parent"
  rm -f "$archive"

  if [[ ! -d "$extracted" ]]; then
    echo "Expected XCFramework was not found after extraction: $extracted" >&2
    exit 1
  fi

  # The release asset directory uses the bundle variant name while the
  # framework contained by the XCFramework is ffmpegkit.framework.
  mv "$extracted" "$destination"

  if [[ "$platform" == "macos" ]]; then
    normalize_macos_xcframework "$destination"
  fi
}

normalize_macos_framework_bundle() {
  local framework="$1"
  local name version_dir source_dir

  [[ -d "$framework" ]] || return 0

  name="$(basename "$framework" .framework)"
  version_dir="$framework/Versions/A"

  # A native macOS framework is a versioned (non-shallow) bundle. The current
  # release asset was packaged with the iOS-style shallow layout, which Xcode
  # embeds successfully but rejects during final application validation.
  if [[ -f "$framework/Versions/Current/Resources/Info.plist" &&         -e "$framework/Versions/Current/$name" ]]; then
    return 0
  fi

  echo "Normalizing macOS framework bundle layout: $framework"

  rm -rf "$framework/_CodeSignature"
  mkdir -p "$version_dir/Resources"

  if [[ -f "$framework/$name" && ! -e "$version_dir/$name" ]]; then
    mv "$framework/$name" "$version_dir/$name"
  fi

  if [[ -f "$framework/Info.plist" ]]; then
    mv "$framework/Info.plist" "$version_dir/Resources/Info.plist"
  fi

  for source_dir in Headers Modules; do
    if [[ -d "$framework/$source_dir" && ! -e "$version_dir/$source_dir" ]]; then
      mv "$framework/$source_dir" "$version_dir/$source_dir"
    fi
  done

  if [[ -d "$framework/Resources" ]]; then
    ditto "$framework/Resources" "$version_dir/Resources"
    rm -rf "$framework/Resources"
  fi

  if [[ ! -f "$version_dir/$name" ]]; then
    echo "macOS framework executable was not found after normalization: $version_dir/$name" >&2
    exit 1
  fi

  if [[ ! -f "$version_dir/Resources/Info.plist" ]]; then
    echo "macOS framework Info.plist was not found after normalization: $version_dir/Resources/Info.plist" >&2
    exit 1
  fi

  rm -f "$framework/Versions/Current"         "$framework/$name"         "$framework/Resources"         "$framework/Headers"         "$framework/Modules"

  ln -s A "$framework/Versions/Current"
  ln -s "Versions/Current/$name" "$framework/$name"
  ln -s "Versions/Current/Resources" "$framework/Resources"

  if [[ -d "$version_dir/Headers" ]]; then
    ln -s "Versions/Current/Headers" "$framework/Headers"
  fi

  if [[ -d "$version_dir/Modules" ]]; then
    ln -s "Versions/Current/Modules" "$framework/Modules"
  fi
}

normalize_macos_xcframework() {
  local xcframework="$1"
  local framework
  local found=0

  while IFS= read -r -d '' framework; do
    found=1
    normalize_macos_framework_bundle "$framework"
  done < <(find "$xcframework" -type d -name 'ffmpegkit.framework' -print0)

  if [[ "$found" -eq 0 ]]; then
    echo "No ffmpegkit.framework was found in macOS XCFramework: $xcframework" >&2
    exit 1
  fi
}

ensure_ios_binary() {
  ensure_apple_binary \
    "ios" \
    "bundle-base-ios-universal-small-lgpl" \
    "$script_dir/vendor/ffmpegkit.xcframework"
}

ensure_macos_binary() {
  ensure_apple_binary \
    "macos" \
    "bundle-base-macos-universal-small-lgpl" \
    "$script_dir/vendor/macos/ffmpegkit.xcframework"
}

prepare_macos_runtime_files() {
  mkdir -p "$macos_runtime_dir"

  # react-native-macos run-macos expects the native macOS project to exist
  # under the React Native project root. Keep the isolated RN-macOS runtime
  # as that root while exposing the unified example/macos project through a
  # symlink. Metro still uses example/ as projectRoot via metro.config.js.
  rm -rf "$macos_runtime_dir/macos"
  ln -s ../macos "$macos_runtime_dir/macos"

  cat > "$macos_runtime_dir/package.json" <<'JSON'
{
  "name": "ffmpeg-kit-extended-react-native-macos-runtime",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "macos": "react-native run-macos --scheme FFmpegKitExtendedExample-macOS",
    "start": "react-native start --config metro.config.js"
  },
  "dependencies": {
    "ffmpeg-kit-extended": "file:.local-packages/ffmpeg-kit-extended-local.tgz",
    "react": "19.1.4",
    "react-native": "0.81.6",
    "react-native-macos": "0.81.8"
  },
  "devDependencies": {
    "@babel/core": "^7.25.2",
    "@babel/preset-env": "^7.25.3",
    "@babel/runtime": "^7.25.0",
    "@react-native-community/cli": "20.0.0",
    "@react-native-community/cli-platform-ios": "20.0.0",
    "@react-native/babel-preset": "0.81.6",
    "@react-native/metro-config": "0.81.6",
    "@react-native/typescript-config": "0.81.6",
    "@types/react": "^19.1.4",
    "typescript": "^5.8.3"
  },
  "engines": {
    "node": ">=20"
  }
}
JSON

  cat > "$macos_runtime_dir/react-native.config.js" <<'JS'
const path = require('path');

module.exports = {
  project: {
    ios: {
      sourceDir: path.resolve(__dirname, '../macos'),
    },
    macos: {
      sourceDir: path.resolve(__dirname, '../macos'),
    },
  },
};
JS

  cat > "$macos_runtime_dir/metro.config.js" <<'JS'
const path = require('path');
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

const runtimeRoot = __dirname;
const exampleRoot = path.resolve(runtimeRoot, '..');
const libraryRoot = path.resolve(exampleRoot, '..');
const runtimeNodeModules = path.resolve(runtimeRoot, 'node_modules');

const config = {
  projectRoot: exampleRoot,
  watchFolders: [libraryRoot],
  resolver: {
    disableHierarchicalLookup: true,
    nodeModulesPaths: [runtimeNodeModules],
    extraNodeModules: {
      react: path.resolve(runtimeNodeModules, 'react'),
      'react-native': path.resolve(runtimeNodeModules, 'react-native'),
      'react-native-macos': path.resolve(runtimeNodeModules, 'react-native-macos'),
      'ffmpeg-kit-extended': path.resolve(runtimeNodeModules, 'ffmpeg-kit-extended'),
    },
  },
};

module.exports = mergeConfig(getDefaultConfig(exampleRoot), config);
JS
}

prepare_macos_package_archive() {
  local package_dir="$macos_runtime_dir/.local-packages"
  local archive="$package_dir/ffmpeg-kit-extended-local.tgz"
  local packed_name

  prepare_macos_runtime_files
  mkdir -p "$package_dir"
  rm -f "$package_dir"/ffmpeg-kit-extended-*.tgz "$archive"

  echo "Packing local FFmpegKit Extended dependency for macOS..."
  packed_name="$(cd "$script_dir" && npm pack --ignore-scripts --pack-destination "$package_dir" | tail -n 1)"

  if [[ -z "$packed_name" || ! -f "$package_dir/$packed_name" ]]; then
    echo "npm pack did not produce the expected local package archive." >&2
    exit 1
  fi

  mv "$package_dir/$packed_name" "$archive"
}

install_macos_dependencies() {
  prepare_macos_package_archive
  rm -rf "$macos_runtime_dir/node_modules/ffmpeg-kit-extended"
  (
    cd "$macos_runtime_dir"
    npm install --ignore-scripts --legacy-peer-deps --no-audit --no-fund
  )
}

sync_macos_codegen_to_runtime() {
  local installed="$macos_runtime_dir/node_modules/ffmpeg-kit-extended"
  if [[ ! -d "$installed" ]]; then
    echo "Installed FFmpegKit Extended package was not found: $installed" >&2
    exit 1
  fi

  rm -rf "$installed/macos/generated"
  mkdir -p "$installed/macos"
  cp -a "$script_dir/macos/generated" "$installed/macos/generated"
}

sync_macos_binary_to_runtime() {
  local installed="$macos_runtime_dir/node_modules/ffmpeg-kit-extended"
  local source="$script_dir/vendor/macos/ffmpegkit.xcframework"
  local destination="$installed/vendor/macos/ffmpegkit.xcframework"

  if [[ ! -d "$installed" ]]; then
    echo "Installed FFmpegKit Extended package was not found: $installed" >&2
    exit 1
  fi

  ensure_macos_binary
  mkdir -p "$(dirname "$destination")"
  rm -rf "$destination"
  echo "Staging FFmpegKit Extended macOS binary for the example app..."
  ditto "$source" "$destination"
}

generate_macos_codegen() {
  local codegen_root="$script_dir/.macos-codegen"
  local codegen_script="$macos_runtime_dir/node_modules/react-native-macos/scripts/generate-codegen-artifacts.js"

  if [[ ! -f "$codegen_script" ]]; then
    echo "React Native macOS Codegen script not found: $codegen_script" >&2
    exit 1
  fi

  rm -rf "$script_dir/macos/generated" "$codegen_root"
  mkdir -p "$script_dir/macos/generated" "$codegen_root"

  cat > "$codegen_root/package.json" <<'JSON'
{
  "name": "ffmpeg-kit-extended-macos-codegen",
  "version": "0.0.0",
  "private": true,
  "codegenConfig": {
    "name": "FFmpegKitExtendedSpec",
    "type": "all",
    "jsSrcsDir": "../src",
    "outputDir": {
      "ios": "../macos/generated"
    },
    "includesGeneratedCode": true,
    "ios": {
      "componentProvider": {
        "FFplayView": "RCTFFplayView"
      }
    }
  }
}
JSON

  echo "Generating React Native macOS Codegen artifacts..."
  node "$codegen_script" -p "$codegen_root" -t ios -s library
  rm -rf "$codegen_root"

  if [[ ! -f "$script_dir/macos/generated/FFmpegKitExtendedSpecJSI.h" ]]; then
    echo "macOS Codegen did not produce FFmpegKitExtendedSpecJSI.h" >&2
    exit 1
  fi
}

prepare_macos_example() {
  install_macos_dependencies
  generate_macos_codegen
  sync_macos_codegen_to_runtime
  sync_macos_binary_to_runtime
}

build_library() {
  echo
  echo "========================================"
  echo "Building React Native library"
  echo "========================================"
  ensure_dependencies "$script_dir"
  npm run prepare
}

build_android() {
  echo
  echo "========================================"
  echo "Building Android example ($build_type)"
  echo "========================================"
  ensure_dependencies "$example_dir"
  local android_arch="${REACT_NATIVE_ARCH:-x86_64}"

  (
    cd "$example_dir/android"
    echo "Generating React Native Codegen artifacts..."
    ./gradlew generateCodegenArtifactsFromSchema
    if [[ "$build_type" == "release" ]]; then
      ./gradlew app:assembleRelease "-PreactNativeArchitectures=$android_arch"
    else
      ./gradlew app:assembleDebug "-PreactNativeArchitectures=$android_arch"
    fi
  )
}

build_ios() {
  if [[ "$host_os" != "Darwin" ]]; then
    echo "Skipping iOS: iOS builds require macOS."
    return
  fi

  echo
  echo "========================================"
  echo "Building iOS example ($build_type)"
  echo "========================================"
  ensure_dependencies "$example_dir"
  ensure_ios_binary

  (
    cd "$example_dir/ios"
    echo "Installing CocoaPods dependencies..."
    bundle exec pod install 2>/dev/null || pod install
    local configuration="Debug"
    [[ "$build_type" == "release" ]] && configuration="Release"
    xcodebuild \
      -workspace FFmpegKitExtendedExample.xcworkspace \
      -scheme FFmpegKitExtendedExample \
      -configuration "$configuration" \
      -sdk iphonesimulator \
      -destination 'generic/platform=iOS Simulator' \
      ARCHS=arm64 \
      ONLY_ACTIVE_ARCH=YES \
      CODE_SIGNING_ALLOWED=NO \
      build
  )
}

build_macos() {
  if [[ "$host_os" != "Darwin" ]]; then
    echo "Skipping macOS: macOS builds require macOS."
    return
  fi

  echo
  echo "========================================"
  echo "Building macOS example ($build_type)"
  echo "========================================"
  prepare_macos_example

  (
    cd "$example_dir/macos"
    echo "Installing CocoaPods dependencies..."
    NODE_PATH="$macos_runtime_dir/node_modules" \
      RCT_NEW_ARCH_ENABLED=1 bundle exec pod install 2>/dev/null || \
    NODE_PATH="$macos_runtime_dir/node_modules" \
      RCT_NEW_ARCH_ENABLED=1 pod install

    local configuration="Debug"
    [[ "$build_type" == "release" ]] && configuration="Release"

    echo "Building macOS app..."
    NODE_PATH="$macos_runtime_dir/node_modules" \
    RCT_NEW_ARCH_ENABLED=1 xcodebuild \
      -workspace FFmpegKitExtendedExample.xcworkspace \
      -scheme FFmpegKitExtendedExample-macOS \
      -configuration "$configuration" \
      -sdk macosx \
      -destination 'platform=macOS' \
      -derivedDataPath "$example_dir/macos/build/DerivedData" \
      CODE_SIGNING_ALLOWED=NO \
      build
  )

  mkdir -p "$example_dir/macos/build"
  touch "$example_dir/macos/build/.last-successful-build"
}

if [[ "$clean_first" == true ]]; then
  clean_project
fi

case "$target" in
  library) build_library ;;
  android) build_library; build_android ;;
  ios) build_library; build_ios ;;
  macos) build_library; build_macos ;;
  all) build_library; build_android; build_ios; build_macos ;;
esac

echo
echo "========================================"
echo "Build completed successfully."
echo "========================================"
