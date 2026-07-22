#!/usr/bin/env bash

set -euo pipefail

case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*)
    export JAVA_HOME="${JAVA_HOME:-/c/Program Files/Java/jdk-17}"
    export PATH="$JAVA_HOME/bin:$PATH"
    ;;
esac

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
example_dir="$script_dir/example"
macos_runtime_dir="$example_dir/.macos-runtime"
appletvos_runtime_dir="$example_dir/.appletvos-runtime"
windows_runtime_dir="$example_dir/.windows-runtime"
linux_runtime_dir="$example_dir/.linux-runtime"
linux_rns_dir="$linux_runtime_dir/src"
linux_depot_tools_dir="$linux_runtime_dir/depot_tools"
linux_example_dir="$example_dir/linux"
linux_rns_revision="${REACT_NATIVE_SKIA_REVISION:-df637f2f4448cb2eaa281c3c0e16825a10afb42e}"
cd "$script_dir"

usage() {
  cat <<'USAGE'
Usage:
  ./build.sh [target] [options]

Targets:
  library     Build the React Native library only
  android     Build the library and Android example
  ios         Build the library and iOS example
  appletvos   Build the library and Apple tvOS example
  macos       Build the library and macOS example
  windows     Build the library and Windows example
  linux       Build the library and Linux example
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
  library|android|ios|appletvos|macos|windows|linux|all) ;;
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

ensure_appletvos_binary() {
  ensure_apple_binary \
    "appletvos" \
    "bundle-base-appletvos-universal-small-lgpl" \
    "$script_dir/vendor/appletvos/ffmpegkit.xcframework"
}

ensure_macos_binary() {
  ensure_apple_binary \
    "macos" \
    "bundle-base-macos-universal-small-lgpl" \
    "$script_dir/vendor/macos/ffmpegkit.xcframework"
}

prepare_appletvos_runtime_files() {
  mkdir -p "$appletvos_runtime_dir"

  rm -rf "$appletvos_runtime_dir/ios"
  ln -s ../appletvos "$appletvos_runtime_dir/ios"

  cat > "$appletvos_runtime_dir/package.json" <<'JSON'
{
  "name": "ffmpeg-kit-extended-react-native-appletvos-runtime",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "start": "react-native start --config metro.config.js"
  },
  "dependencies": {
    "ffmpeg-kit-extended": "file:.local-packages/ffmpeg-kit-extended-local.tgz",
    "react": "19.2.3",
    "react-native": "npm:react-native-tvos@0.86.0-2"
  },
  "devDependencies": {
    "@babel/core": "^7.25.2",
    "@babel/preset-env": "^7.25.3",
    "@babel/runtime": "^7.25.0",
    "@react-native-community/cli": "20.1.0",
    "@react-native-community/cli-platform-ios": "20.1.0",
    "@react-native/babel-preset": "0.86.0",
    "@react-native/metro-config": "0.86.0",
    "@react-native/typescript-config": "0.86.0",
    "@types/react": "^19.2.0",
    "typescript": "^5.8.3"
  },
  "engines": {
    "node": ">=22.11.0"
  }
}
JSON

  cat > "$appletvos_runtime_dir/react-native.config.js" <<'JS'
const path = require('path');

module.exports = {
  project: {
    ios: {
      sourceDir: path.resolve(__dirname, '../appletvos'),
    },
  },
};
JS

  cat > "$appletvos_runtime_dir/metro.config.js" <<'JS'
const path = require('path');
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

const runtimeRoot = __dirname;
const exampleRoot = path.resolve(runtimeRoot, '..');
const libraryRoot = path.resolve(exampleRoot, '..');
const runtimeNodeModules = path.resolve(runtimeRoot, 'node_modules');
const defaultConfig = getDefaultConfig(exampleRoot);

const config = {
  projectRoot: exampleRoot,
  watchFolders: [libraryRoot],
  resolver: {
    disableHierarchicalLookup: true,
    nodeModulesPaths: [runtimeNodeModules],
    sourceExts: defaultConfig.resolver.sourceExts.flatMap(ext => [
      `tv.${ext}`,
      ext,
    ]),
    extraNodeModules: {
      react: path.resolve(runtimeNodeModules, 'react'),
      'react-native': path.resolve(runtimeNodeModules, 'react-native'),
      'ffmpeg-kit-extended': path.resolve(runtimeNodeModules, 'ffmpeg-kit-extended'),
    },
  },
};

module.exports = mergeConfig(defaultConfig, config);
JS
}

prepare_appletvos_package_archive() {
  local package_dir="$appletvos_runtime_dir/.local-packages"
  local archive="$package_dir/ffmpeg-kit-extended-local.tgz"
  local packed_name

  prepare_appletvos_runtime_files
  mkdir -p "$package_dir"
  rm -f "$package_dir"/ffmpeg-kit-extended-*.tgz "$archive"

  echo "Packing local FFmpegKit Extended dependency for Apple tvOS..."
  packed_name="$(cd "$script_dir" && npm pack --ignore-scripts --pack-destination "$package_dir" | tail -n 1)"

  if [[ -z "$packed_name" || ! -f "$package_dir/$packed_name" ]]; then
    echo "npm pack did not produce the expected local package archive." >&2
    exit 1
  fi

  mv "$package_dir/$packed_name" "$archive"
}

install_appletvos_dependencies() {
  prepare_appletvos_package_archive
  rm -rf "$appletvos_runtime_dir/node_modules/ffmpeg-kit-extended"
  (
    cd "$appletvos_runtime_dir"
    npm install --ignore-scripts --legacy-peer-deps --no-audit --no-fund
  )
}

sync_appletvos_codegen_to_runtime() {
  local installed="$appletvos_runtime_dir/node_modules/ffmpeg-kit-extended"
  if [[ ! -d "$installed" ]]; then
    echo "Installed FFmpegKit Extended package was not found: $installed" >&2
    exit 1
  fi

  rm -rf "$installed/appletvos/generated"
  mkdir -p "$installed/appletvos"
  cp -a "$script_dir/appletvos/generated" "$installed/appletvos/generated"
}

sync_appletvos_binary_to_runtime() {
  local installed="$appletvos_runtime_dir/node_modules/ffmpeg-kit-extended"
  local source="$script_dir/vendor/appletvos/ffmpegkit.xcframework"
  local destination="$installed/vendor/appletvos/ffmpegkit.xcframework"

  if [[ ! -d "$installed" ]]; then
    echo "Installed FFmpegKit Extended package was not found: $installed" >&2
    exit 1
  fi

  ensure_appletvos_binary
  mkdir -p "$(dirname "$destination")"
  rm -rf "$destination"
  echo "Staging FFmpegKit Extended Apple tvOS binary for the example app..."
  ditto "$source" "$destination"
}

generate_appletvos_codegen() {
  local codegen_root="$script_dir/.appletvos-codegen"
  local codegen_script="$appletvos_runtime_dir/node_modules/react-native/scripts/generate-codegen-artifacts.js"

  if [[ ! -f "$codegen_script" ]]; then
    echo "React Native tvOS Codegen script not found: $codegen_script" >&2
    exit 1
  fi

  rm -rf "$script_dir/appletvos/generated" "$codegen_root"
  mkdir -p "$script_dir/appletvos/generated" "$codegen_root"

  cat > "$codegen_root/package.json" <<'JSON'
{
  "name": "ffmpeg-kit-extended-appletvos-codegen",
  "version": "0.0.0",
  "private": true,
  "codegenConfig": {
    "name": "FFmpegKitExtendedSpec",
    "type": "all",
    "jsSrcsDir": "../src",
    "outputDir": {
      "ios": "../appletvos/generated"
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

  echo "Generating React Native Apple tvOS Codegen artifacts..."
  node "$codegen_script" -p "$codegen_root" -t ios -s library
  rm -rf "$codegen_root"

  if [[ ! -f "$script_dir/appletvos/generated/ReactCodegen/FFmpegKitExtendedSpecJSI.h" ]]; then
    echo "Apple tvOS Codegen did not produce ReactCodegen/FFmpegKitExtendedSpecJSI.h" >&2
    exit 1
  fi
}

prepare_appletvos_example() {
  install_appletvos_dependencies
  generate_appletvos_codegen
  sync_appletvos_codegen_to_runtime
  sync_appletvos_binary_to_runtime
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


prepare_windows_runtime_files() {
  mkdir -p "$windows_runtime_dir"

  cat > "$windows_runtime_dir/package.json" <<'JSON'
{
  "name": "ffmpeg-kit-extended-react-native-windows-runtime",
  "version": "0.0.1",
  "private": true,
  "scripts": {
    "start": "react-native start --config metro.config.js",
    "windows": "react-native run-windows --sln ../windows/FFmpegKitExtendedExample.sln"
  },
  "dependencies": {
    "ffmpeg-kit-extended": "file:.local-packages/ffmpeg-kit-extended-local.tgz",
    "react": "19.2.3",
    "react-native": "0.84.0",
    "react-native-windows": "0.84.0"
  },
  "devDependencies": {
    "@babel/core": "^7.25.2",
    "@babel/runtime": "^7.25.0",
    "@react-native-community/cli": "20.0.0",
    "@react-native/babel-preset": "0.84.0",
    "@react-native/metro-config": "0.84.0",
    "@react-native/typescript-config": "0.84.0",
    "@types/react": "^19.2.0",
    "typescript": "^5.8.3"
  },
  "engines": {
    "node": ">=22.11.0"
  }
}
JSON

  cat > "$windows_runtime_dir/react-native.config.js" <<'JS'
const path = require('path');

module.exports = {
  project: {
    windows: {
      sourceDir: '../windows',
      solutionFile: 'FFmpegKitExtendedExample.sln',
      project: {
        projectFile: 'FFmpegKitExtendedExample\\FFmpegKitExtendedExample.vcxproj',
      },
    },
  },
};
JS

  cat > "$windows_runtime_dir/metro.config.js" <<'JS'
const path = require('path');
const {getDefaultConfig, mergeConfig} = require('@react-native/metro-config');

const runtimeRoot = __dirname;
const exampleRoot = path.resolve(runtimeRoot, '..');
const libraryRoot = path.resolve(exampleRoot, '..');
const runtimeNodeModules = path.resolve(runtimeRoot, 'node_modules');
const windowsRoot = path.resolve(exampleRoot, 'windows').replace(/[/\\]/g, '/');

const config = {
  projectRoot: exampleRoot,
  watchFolders: [libraryRoot],
  resolver: {
    disableHierarchicalLookup: true,
    nodeModulesPaths: [runtimeNodeModules],
    blockList: [new RegExp(`${windowsRoot}.*`)],
    extraNodeModules: {
      react: path.resolve(runtimeNodeModules, 'react'),
      'react-native': path.resolve(runtimeNodeModules, 'react-native'),
      'react-native-windows': path.resolve(runtimeNodeModules, 'react-native-windows'),
      'ffmpeg-kit-extended': path.resolve(runtimeNodeModules, 'ffmpeg-kit-extended'),
    },
  },
};

module.exports = mergeConfig(getDefaultConfig(exampleRoot), config);
JS
}

prepare_windows_package_archive() {
  local package_dir="$windows_runtime_dir/.local-packages"
  local archive="$package_dir/ffmpeg-kit-extended-local.tgz"
  local packed_name

  prepare_windows_runtime_files
  mkdir -p "$package_dir"
  rm -f "$package_dir"/ffmpeg-kit-extended-*.tgz "$archive"

  echo "Packing local FFmpegKit Extended dependency for Windows..."
  packed_name="$(cd "$script_dir" && npm pack --ignore-scripts --pack-destination "$package_dir" | tail -n 1)"
  if [[ -z "$packed_name" || ! -f "$package_dir/$packed_name" ]]; then
    echo "npm pack did not produce the expected local package archive." >&2
    exit 1
  fi
  mv "$package_dir/$packed_name" "$archive"
}

prepare_windows_example() {
  prepare_windows_package_archive
  rm -rf "$windows_runtime_dir/node_modules/ffmpeg-kit-extended"
  (
    cd "$windows_runtime_dir"
    npm install --ignore-scripts --legacy-peer-deps --no-audit --no-fund
  )

  # Stage the native FFmpegKit runtime before MSBuild evaluates the packaging
  # project. The WAP project includes this flattened directory as package
  # content so libffmpegkit.dll and its dependent DLLs are deployed next to
  # the application executable.
  local runtime_stage_dir="$example_dir/windows/build/runtime/x64"
  local runtime_script="$windows_runtime_dir/node_modules/ffmpeg-kit-extended/scripts/prepare-windows-runtime.ps1"
  local runtime_stage_dir_win runtime_script_win

  rm -rf "$runtime_stage_dir"
  mkdir -p "$runtime_stage_dir"

  runtime_stage_dir_win="$(cygpath -w "$runtime_stage_dir")"
  runtime_script_win="$(cygpath -w "$runtime_script")"

  echo "Staging FFmpegKit Extended Windows runtime DLLs..."
  MSYS2_ARG_CONV_EXCL='*' powershell.exe \
    -NoProfile \
    -ExecutionPolicy Bypass \
    -File "$runtime_script_win" \
    -Architecture x64 \
    -Destination "$runtime_stage_dir_win" >/dev/null

  if [[ ! -f "$runtime_stage_dir/libffmpegkit.dll" && ! -f "$runtime_stage_dir/ffmpegkit.dll" ]]; then
    echo "FFmpegKit Windows runtime staging did not produce libffmpegkit.dll or ffmpegkit.dll in: $runtime_stage_dir" >&2
    exit 1
  fi

  (
    cd "$windows_runtime_dir"
    npx react-native autolink-windows --no-telemetry
  )
}


is_linux_host() {
  [[ "$host_os" == "Linux" ]]
}

run_linux_yarn() {
  if command -v yarn >/dev/null 2>&1; then
    yarn "$@"
  elif command -v corepack >/dev/null 2>&1; then
    corepack yarn@1.22.22 "$@"
  else
    echo "Linux example setup requires Yarn or Corepack." >&2
    exit 1
  fi
}

run_linux_git_lf() {
  env \
    GIT_CONFIG_COUNT=1 \
    GIT_CONFIG_KEY_0=core.autocrlf \
    GIT_CONFIG_VALUE_0=false \
    "$@"
}

normalize_linux_git_checkout() {
  local repo="$1"

  [[ -d "$repo/.git" ]] || return 0

  # WSL can inherit core.autocrlf=true from Windows Git configuration. That
  # checks executable scripts out with CRLF endings, causing shebang failures
  # such as `/usr/bin/env: 'bash\r': No such file or directory`. Keep the
  # generated Linux runtime checkout LF-only without changing the user's global
  # Git configuration.
  git -C "$repo" config core.autocrlf false
  git -C "$repo" checkout -f -- .
}

ensure_linux_depot_tools() {
  if command -v gclient >/dev/null 2>&1; then
    return
  fi

  if [[ ! -d "$linux_depot_tools_dir/.git" ]]; then
    mkdir -p "$linux_runtime_dir"
    echo "Bootstrapping Chromium depot_tools for the Linux React Native host..."
    run_linux_git_lf git clone --depth 1 \
      https://chromium.googlesource.com/chromium/tools/depot_tools.git \
      "$linux_depot_tools_dir"
  fi

  normalize_linux_git_checkout "$linux_depot_tools_dir"
  export PATH="$linux_depot_tools_dir:$PATH"
}

ensure_linux_react_native_skia() {
  local source_url="https://github.com/react-native-skia/react-native-skia.git"

  ensure_linux_depot_tools
  mkdir -p "$linux_runtime_dir"

  if [[ ! -d "$linux_rns_dir/.git" ]]; then
    echo "Cloning React Native Skia Linux host..."
    run_linux_git_lf git clone "$source_url" "$linux_rns_dir"
  fi

  normalize_linux_git_checkout "$linux_rns_dir"
  run_linux_git_lf git -C "$linux_rns_dir" checkout --detach "$linux_rns_revision"

  if [[ ! -f "$linux_runtime_dir/.gclient" ]]; then
    (
      cd "$linux_runtime_dir"
      run_linux_git_lf gclient config --name src --unmanaged "$source_url"
    )
  fi

  if [[ ! -f "$linux_runtime_dir/.deps-synced" ]]; then
    echo "Syncing React Native Skia native dependencies..."
    (
      cd "$linux_runtime_dir"
      run_linux_git_lf gclient sync --with_branch_heads
    )
    touch "$linux_runtime_dir/.deps-synced"
  fi

  if [[ ! -d "$linux_rns_dir/node_modules/react-native" ]]; then
    echo "Installing React Native Skia JavaScript dependencies..."
    (
      cd "$linux_rns_dir"
      run_linux_yarn install --frozen-lockfile
    )
  fi
}

prepare_linux_package_archive() {
  local package_dir="$linux_rns_dir/.local-packages"
  local archive="$package_dir/ffmpeg-kit-extended-local.tgz"
  local packed_name

  mkdir -p "$package_dir"
  rm -f "$package_dir"/ffmpeg-kit-extended-*.tgz "$archive"

  echo "Packing local FFmpegKit Extended dependency for Linux..." >&2
  packed_name="$(cd "$script_dir" && npm pack --ignore-scripts --pack-destination "$package_dir" | tail -n 1)"
  if [[ -z "$packed_name" || ! -f "$package_dir/$packed_name" ]]; then
    echo "npm pack did not produce the expected Linux package archive." >&2
    exit 1
  fi

  mv "$package_dir/$packed_name" "$archive"
  printf '%s\n' "$archive"
}

prepare_linux_example() {
  local archive

  ensure_linux_react_native_skia
  archive="$(prepare_linux_package_archive)"

  python3 "$script_dir/scripts/prepare-linux-react-native-skia.py" \
    "$linux_rns_dir" \
    "$script_dir" \
    "$archive"
}

build_linux() {
  if ! is_linux_host; then
    echo "Skipping Linux: Linux builds require a Linux host."
    return
  fi

  echo
  echo "========================================"
  echo "Building Linux example ($build_type)"
  echo "========================================"
  prepare_linux_example

  local configuration="Debug"
  local is_debug="true"
  if [[ "$build_type" == "release" ]]; then
    configuration="Release"
    is_debug="false"
  fi

  local runtime_output="$linux_rns_dir/out/$configuration"
  local staged_output="$linux_example_dir/build/$configuration"
  local gn_args
  gn_args="use_sysroot=false enable_vulkan=false icu_use_data_file=false skia_use_system_nopoll=true gl_use_glx=false is_debug=$is_debug is_component_build=true enable_precompiled_headers=true"

  echo "Generating React Native Skia Linux build files..."
  (
    cd "$linux_rns_dir"
    gn gen "out/$configuration" --args="$gn_args"
    ninja -C "out/$configuration" ReactSkiaApp
  )

  echo "Bundling unified React Native example for Linux..."
  (
    cd "$linux_rns_dir"
    run_linux_yarn workspace react-native-skia run react-native bundle \
      --platform ios \
      --dev false \
      --entry-file FFmpegKitExtendedExample.js \
      --bundle-output "../../out/$configuration/SimpleViewApp.bundle" \
      --assets-dest "../../out/$configuration"
  )

  rm -rf "$staged_output"
  mkdir -p "$staged_output"
  cp -a "$runtime_output/." "$staged_output/"

  echo "Staging FFmpegKit Extended Linux runtime libraries..."
  "$script_dir/scripts/prepare-linux-runtime.sh" "$(uname -m)" "$staged_output" >/dev/null

  if [[ ! -x "$staged_output/ReactSkiaApp" ]]; then
    echo "React Native Skia Linux executable was not produced: $staged_output/ReactSkiaApp" >&2
    exit 1
  fi

  if [[ ! -f "$staged_output/libffmpegkit.so" ]]; then
    echo "FFmpegKit Linux runtime staging did not produce libffmpegkit.so in: $staged_output" >&2
    exit 1
  fi

  touch "$linux_example_dir/build/.last-successful-build"
}

is_windows_host() {
  case "$host_os" in
    MINGW*|MSYS*|CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

build_windows() {
  if ! is_windows_host; then
    echo "Skipping Windows: Windows builds require a Windows host."
    return
  fi

  echo
  echo "========================================"
  echo "Building Windows example ($build_type)"
  echo "========================================"
  prepare_windows_example

  local -a args=(
    react-native run-windows
    --sln ../windows/FFmpegKitExtendedExample.sln
    --arch x64
    --no-packager
    --no-launch
    --no-deploy
  )
  if [[ "$build_type" == "release" ]]; then
    args+=(--release)
  fi

  (cd "$windows_runtime_dir" && npx "${args[@]}")
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

build_appletvos() {
  if [[ "$host_os" != "Darwin" ]]; then
    echo "Skipping Apple tvOS: tvOS builds require macOS."
    return
  fi

  echo
  echo "========================================"
  echo "Building Apple tvOS example ($build_type)"
  echo "========================================"
  prepare_appletvos_example

  (
    cd "$example_dir/appletvos"
    echo "Installing CocoaPods dependencies..."
    NODE_PATH="$appletvos_runtime_dir/node_modules" \
      RCT_NEW_ARCH_ENABLED=1 bundle exec pod install 2>/dev/null || \
    NODE_PATH="$appletvos_runtime_dir/node_modules" \
      RCT_NEW_ARCH_ENABLED=1 pod install

    local configuration="Debug"
    [[ "$build_type" == "release" ]] && configuration="Release"

    echo "Building Apple tvOS app..."
    NODE_PATH="$appletvos_runtime_dir/node_modules" \
    RCT_NEW_ARCH_ENABLED=1 xcodebuild \
      -workspace FFmpegKitExtendedExample.xcworkspace \
      -scheme FFmpegKitExtendedExample \
      -configuration "$configuration" \
      -sdk appletvsimulator \
      -destination 'generic/platform=tvOS Simulator' \
      -derivedDataPath "$example_dir/appletvos/build/DerivedData" \
      ARCHS=arm64 \
      ONLY_ACTIVE_ARCH=YES \
      CODE_SIGNING_ALLOWED=NO \
      build
  )

  mkdir -p "$example_dir/appletvos/build"
  touch "$example_dir/appletvos/build/.last-successful-build"
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
  appletvos) build_library; build_appletvos ;;
  macos) build_library; build_macos ;;
  windows) build_library; build_windows ;;
  linux) build_library; build_linux ;;
  all) build_library; build_android; build_ios; build_appletvos; build_macos; build_windows; build_linux ;;
esac

echo
echo "========================================"
echo "Build completed successfully."
echo "========================================"
