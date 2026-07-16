#!/usr/bin/env bash

set -euo pipefail

export JAVA_HOME="/c/Program Files/Java/jdk-17"
export PATH="$JAVA_HOME/bin:$PATH"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

usage() {
  cat <<'EOF'
Usage:
  ./build.sh [target] [options]

Targets:
  library     Build the React Native library only
  android     Build the library and Android example
  ios         Build the library and iOS example
  all         Build all supported targets for the current host

Options:
  --clean     Run ./clean before building
  --release   Build example apps in release mode
  -h, --help  Show this help

Examples:
  ./build library
  ./build android
  ./build android --clean
  ./build android --release
  ./build ios
  ./build all --clean
EOF
}

target="${1:-all}"
clean_first=false
build_type="debug"

if [[ $# -gt 0 ]]; then
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --clean)
      clean_first=true
      ;;
    --release)
      build_type="release"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac

  shift
done

case "$target" in
  library|android|ios|all)
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "Unknown target: $target" >&2
    usage
    exit 1
    ;;
esac

host_os="$(uname -s)"

ensure_dependencies() {
  local dir="$1"

  if [[ ! -d "$dir/node_modules" ]]; then
    echo "Installing dependencies in $dir..."
    (
      cd "$dir"
      npm install
    )
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

  ensure_dependencies "$script_dir/example"

  local android_arch="${REACT_NATIVE_ARCH:-x86_64}"

  (
    cd "$script_dir/example/android"

    echo "Generating React Native Codegen artifacts..."
    ./gradlew generateCodegenArtifactsFromSchema

    if [[ "$build_type" == "release" ]]; then
      echo "Building Android release APK for: $android_arch"

      ./gradlew \
        app:assembleRelease \
        "-PreactNativeArchitectures=$android_arch"
    else
      echo "Building Android debug APK for: $android_arch"

      ./gradlew \
        app:assembleDebug \
        "-PreactNativeArchitectures=$android_arch"
    fi
  )

  if [[ "$build_type" == "release" ]]; then
    echo
    echo "Android output:"
    echo "  example/android/app/build/outputs/apk/release/"
  else
    echo
    echo "Android output:"
    echo "  example/android/app/build/outputs/apk/debug/"
  fi
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

  ensure_dependencies "$script_dir/example"

  (
    cd "$script_dir/example/ios"

    echo "Installing CocoaPods dependencies..."
    bundle exec pod install 2>/dev/null || pod install

    if [[ "$build_type" == "release" ]]; then
      configuration="Release"
    else
      configuration="Debug"
    fi

    echo "Building iOS simulator app..."

    xcodebuild \
      -workspace FFmpegKitExtendedExample.xcworkspace \
      -scheme FFmpegKitExtendedExample \
      -configuration "$configuration" \
      -sdk iphonesimulator \
      -destination 'generic/platform=iOS Simulator' \
      CODE_SIGNING_ALLOWED=NO \
      build
  )
}

if [[ "$clean_first" == true ]]; then
  echo "Cleaning previous build artifacts..."
  clean_project
fi

case "$target" in
  library)
    build_library
    ;;

  android)
    build_library
    build_android
    ;;

  ios)
    build_library
    build_ios
    ;;

  all)
    build_library
    build_android
    build_ios
    ;;
esac

echo
echo "========================================"
echo "Build completed successfully."
echo "========================================"