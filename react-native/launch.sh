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

    echo "Preparing macOS example..."
    # Calling the macOS build preparation through build.sh keeps the isolated
    # RN-macOS runtime and native dependency staging identical for build/launch.
    "$script_dir/build.sh" library

    # Define the same preparation helpers used by build.sh in this shell.
    # shellcheck disable=SC1090
    source <(
      sed -n '/^ensure_apple_binary()/,/^build_library()/p' "$script_dir/build.sh" | \
        sed '$d'
    )
    prepare_macos_example

    (
      cd "$example_dir/macos"
      echo "Installing CocoaPods dependencies..."
      NODE_PATH="$macos_runtime_dir/node_modules" \
        RCT_NEW_ARCH_ENABLED=1 bundle exec pod install 2>/dev/null || \
      NODE_PATH="$macos_runtime_dir/node_modules" \
        RCT_NEW_ARCH_ENABLED=1 pod install
    )

    cd "$macos_runtime_dir"
    exec env \
      NODE_PATH="$macos_runtime_dir/node_modules" \
      RCT_NEW_ARCH_ENABLED=1 \
      npm run macos
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
