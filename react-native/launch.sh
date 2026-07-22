#!/usr/bin/env bash

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  export JAVA_HOME="${JAVA_HOME:-/c/Program Files/Java/jdk-17}"
  export PATH="$JAVA_HOME/bin:$PATH"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
example_dir="$script_dir/example"
macos_runtime_dir="$example_dir/.macos-runtime"
target="${1:-android}"

usage() {
  cat <<'USAGE'
Usage:
  ./launch.sh [android|ios|macos]
USAGE
}

ensure_dependencies() {
  local dir="$1"
  if [[ ! -d "$dir/node_modules" ]]; then
    (cd "$dir" && npm install)
  fi
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
