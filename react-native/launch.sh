#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  export JAVA_HOME="${JAVA_HOME:-/c/Program Files/Java/jdk-17}"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
example_dir="$script_dir/example"
macos_runtime_dir="$example_dir/.macos-runtime"
appletvos_runtime_dir="$example_dir/.appletvos-runtime"
target="${1:-android}"

usage() {
  cat <<'USAGE'
Usage:
  ./launch.sh [android|ios|appletvos|macos]
USAGE
}

ensure_dependencies() {
  local dir="$1"
  if [[ ! -d "$dir/node_modules" ]]; then
    (cd "$dir" && npm install)
  fi
}

appletvos_app_path="$example_dir/appletvos/build/DerivedData/Build/Products/Debug-appletvsimulator/FFmpegKitExtendedExample.app"
appletvos_build_stamp="$example_dir/appletvos/build/.last-successful-build"

appletvos_build_required() {
  if [[ ! -d "$appletvos_app_path" || ! -f "$appletvos_build_stamp" ]]; then
    return 0
  fi

  local source
  local -a sources=(
    "$script_dir/src"
    "$script_dir/cpp"
    "$script_dir/appletvos"
    "$script_dir/package.json"
    "$script_dir/FFmpegKitExtended.podspec"
    "$script_dir/react-native.config.js"
    "$script_dir/build.sh"
    "$example_dir/App.tv.tsx"
    "$example_dir/index.js"
    "$example_dir/package.json"
    "$example_dir/src"
    "$example_dir/appletvos/Podfile"
    "$example_dir/appletvos/FFmpegKitExtendedExample"
    "$example_dir/appletvos/FFmpegKitExtendedExample.xcodeproj"
    "$script_dir/vendor/appletvos"
  )

  for source in "${sources[@]}"; do
    if [[ -f "$source" ]]; then
      if [[ "$source" -nt "$appletvos_build_stamp" ]]; then
        return 0
      fi
    elif [[ -d "$source" ]]; then
      if find "$source" -type f -newer "$appletvos_build_stamp" -print -quit 2>/dev/null | grep -q .; then
        return 0
      fi
    fi
  done

  return 1
}

macos_app_path="$example_dir/macos/build/DerivedData/Build/Products/Debug/FFmpegKitExtendedExample.app"
macos_build_stamp="$example_dir/macos/build/.last-successful-build"

macos_build_required() {
  if [[ ! -d "$macos_app_path" || ! -f "$macos_build_stamp" ]]; then
    return 0
  fi

  local source
  local -a sources=(
    "$script_dir/src"
    "$script_dir/cpp"
    "$script_dir/macos"
    "$script_dir/package.json"
    "$script_dir/FFmpegKitExtended.podspec"
    "$script_dir/react-native.config.js"
    "$script_dir/build.sh"
    "$example_dir/App.tsx"
    "$example_dir/index.js"
    "$example_dir/package.json"
    "$example_dir/metro.config.js"
    "$example_dir/src"
    "$example_dir/macos/Podfile"
    "$example_dir/macos/FFmpegKitExtendedExample-macOS"
    "$example_dir/macos/FFmpegKitExtendedExample.xcodeproj"
    "$script_dir/vendor/macos"
  )

  for source in "${sources[@]}"; do
    if [[ -f "$source" ]]; then
      if [[ "$source" -nt "$macos_build_stamp" ]]; then
        return 0
      fi
    elif [[ -d "$source" ]]; then
      if find "$source" -type f -newer "$macos_build_stamp" -print -quit 2>/dev/null | grep -q .; then
        return 0
      fi
    fi
  done

  return 1
}

case "$target" in
  android)
    echo "Launching Android example..."
    ensure_dependencies "$example_dir"
    cd "$example_dir"
    exec npm run android -- --active-arch-only
    ;;

  ios)
    if [[ "$(uname -s)" != "Darwin" ]]; then
      echo "Error: iOS can only be launched from macOS." >&2
      exit 1
    fi
    echo "Launching iOS example..."
    ensure_dependencies "$example_dir"
    cd "$example_dir"
    exec npm run ios
    ;;

  appletvos)
    if [[ "$(uname -s)" != "Darwin" ]]; then
      echo "Error: Apple tvOS can only be launched from macOS." >&2
      exit 1
    fi

    if appletvos_build_required; then
      echo "Apple tvOS sources changed or no successful build was found; rebuilding..."
      "$script_dir/build.sh" appletvos
    else
      echo "Reusing existing Apple tvOS build; no relevant source changes detected."
    fi

    if [[ ! -d "$appletvos_app_path" ]]; then
      echo "Built Apple tvOS application was not found: $appletvos_app_path" >&2
      exit 1
    fi

    if ! lsof -nP -iTCP:8081 -sTCP:LISTEN >/dev/null 2>&1; then
      echo "Starting Metro on port 8081..."
      (
        cd "$appletvos_runtime_dir"
        nohup npm run start -- --port 8081 \
          > "$appletvos_runtime_dir/metro.log" 2>&1 &
        echo $! > "$appletvos_runtime_dir/metro.pid"
      )

      for _ in {1..20}; do
        if lsof -nP -iTCP:8081 -sTCP:LISTEN >/dev/null 2>&1; then
          break
        fi
        sleep 0.25
      done

      if ! lsof -nP -iTCP:8081 -sTCP:LISTEN >/dev/null 2>&1; then
        echo "Metro did not start successfully. See: $appletvos_runtime_dir/metro.log" >&2
        exit 1
      fi
    else
      echo "Metro is already running on port 8081."
    fi

    device_udid="$(
      xcrun simctl list devices available |
        grep 'Apple TV' |
        head -n 1 |
        grep -Eo '[0-9A-Fa-f-]{36}' || true
    )"

    if [[ -z "$device_udid" ]]; then
      echo "No available Apple TV simulator was found." >&2
      exit 1
    fi

    xcrun simctl boot "$device_udid" >/dev/null 2>&1 || true
    open -a Simulator
    xcrun simctl bootstatus "$device_udid" -b
    xcrun simctl install "$device_udid" "$appletvos_app_path"

    echo "Launching Apple tvOS example..."
    exec xcrun simctl launch \
      "$device_udid" \
      org.reactjs.native.example.FFmpegKitExtendedExample
    ;;

  macos)
    if [[ "$(uname -s)" != "Darwin" ]]; then
      echo "Error: macOS can only be launched from macOS." >&2
      exit 1
    fi

    if macos_build_required; then
      echo "macOS sources changed or no successful build was found; rebuilding..."
      "$script_dir/build.sh" macos
    else
      echo "Reusing existing macOS build; no relevant source changes detected."
    fi

    if [[ ! -d "$macos_app_path" ]]; then
      echo "Built macOS application was not found: $macos_app_path" >&2
      exit 1
    fi

    # The macOS host loads the Debug JavaScript bundle from Metro. Start Metro
    # from the isolated RN-macOS runtime, whose metro.config.js points projectRoot
    # at the shared example/ application.
    if ! lsof -nP -iTCP:8081 -sTCP:LISTEN >/dev/null 2>&1; then
      echo "Starting Metro on port 8081..."
      (
        cd "$macos_runtime_dir"
        nohup npm run start -- --port 8081 \
          > "$macos_runtime_dir/metro.log" 2>&1 &
        echo $! > "$macos_runtime_dir/metro.pid"
      )

      # Give Metro a brief opportunity to bind before launching the app.
      for _ in {1..20}; do
        if lsof -nP -iTCP:8081 -sTCP:LISTEN >/dev/null 2>&1; then
          break
        fi
        sleep 0.25
      done

      if ! lsof -nP -iTCP:8081 -sTCP:LISTEN >/dev/null 2>&1; then
        echo "Metro did not start successfully. See: $macos_runtime_dir/metro.log" >&2
        exit 1
      fi
    else
      echo "Metro is already running on port 8081."
    fi

    echo "Launching macOS example..."
    exec open -n "$macos_app_path"
    ;;

  -h|--help)
    usage
    ;;

  *)
    echo "Unknown target: $target" >&2
    usage
    exit 1
    ;;
esac
