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

metro_listener_pid() {
  lsof -nP -tiTCP:8081 -sTCP:LISTEN 2>/dev/null | head -n 1 || true
}

process_working_directory() {
  local pid="$1"
  lsof -a -p "$pid" -d cwd -Fn 2>/dev/null |
    sed -n 's/^n//p' |
    head -n 1 || true
}

wait_for_metro_port_to_close() {
  for _ in {1..40}; do
    if [[ -z "$(metro_listener_pid)" ]]; then
      return 0
    fi
    sleep 0.25
  done
  return 1
}

stop_conflicting_project_metro() {
  local expected_runtime_dir="$1"
  local label="$2"
  local pid cwd expected_cwd

  pid="$(metro_listener_pid)"
  [[ -n "$pid" ]] || return 0

  cwd="$(process_working_directory "$pid")"
  expected_cwd="$(cd "$expected_runtime_dir" && pwd -P)"

  if [[ "$cwd" == "$expected_cwd" ]]; then
    # Older versions of launch.sh started Metro with nohup and left only a log
    # file in the runtime directory. Restart that server in Terminal once so
    # Metro remains visible and interactive on subsequent launches.
    if [[ -f "$expected_runtime_dir/metro.pid" ]]; then
      echo "Restarting background $label Metro in Terminal..."
      kill "$pid" >/dev/null 2>&1 || true
      rm -f "$expected_runtime_dir/metro.pid"
      if ! wait_for_metro_port_to_close; then
        echo "Unable to stop the existing $label Metro process on port 8081." >&2
        exit 1
      fi
      return 0
    fi

    echo "$label Metro is already running in the expected runtime on port 8081."
    return 1
  fi

  # The Apple example runtimes intentionally use different React Native forks.
  # Reusing a Metro server from another runtime can serve an incompatible JS
  # bundle (for example react-native-macos to react-native-tvos), which manifests
  # as missing core TurboModules such as PlatformConstants at startup.
  if [[ -n "$cwd" && ( "$cwd" == "$script_dir" || "$cwd" == "$script_dir"/* ) ]]; then
    echo "Switching Metro to $label (stopping project Metro from $cwd)..."
    kill "$pid" >/dev/null 2>&1 || true
    rm -f "$macos_runtime_dir/metro.pid" "$appletvos_runtime_dir/metro.pid"
    if ! wait_for_metro_port_to_close; then
      echo "Unable to stop the conflicting project Metro process on port 8081." >&2
      exit 1
    fi
    return 0
  fi

  echo "Port 8081 is already in use by PID $pid${cwd:+ (cwd: $cwd)}." >&2
  echo "Stop that process before launching the $label example so it does not receive the wrong Metro bundle." >&2
  exit 1
}

start_metro_in_terminal() {
  local runtime_dir="$1"
  local label="$2"
  local launcher="$runtime_dir/.start-metro.command"
  local quoted_runtime

  printf -v quoted_runtime '%q' "$runtime_dir"
  cat > "$launcher" <<EOF
#!/usr/bin/env bash
cd $quoted_runtime
printf '\\033]0;Metro - $label\\007'
exec npm run start -- --port 8081 --reset-cache
EOF
  chmod +x "$launcher"

  echo "Opening $label Metro in Terminal on port 8081..."
  open -a Terminal "$launcher"

  for _ in {1..80}; do
    if [[ -n "$(metro_listener_pid)" ]]; then
      return 0
    fi
    sleep 0.25
  done

  echo "$label Metro did not start successfully in Terminal." >&2
  exit 1
}

ensure_metro_in_terminal() {
  local runtime_dir="$1"
  local label="$2"

  if stop_conflicting_project_metro "$runtime_dir" "$label"; then
    start_metro_in_terminal "$runtime_dir" "$label"
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

    ensure_metro_in_terminal "$appletvos_runtime_dir" "Apple tvOS"

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

    # The macOS host loads the Debug JavaScript bundle from Metro. The macOS and
    # Apple tvOS examples use different React Native runtimes, so never reuse a
    # project Metro process that belongs to the other Apple platform.
    ensure_metro_in_terminal "$macos_runtime_dir" "macOS"

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
