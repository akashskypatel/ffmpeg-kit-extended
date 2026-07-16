#!/usr/bin/env bash

set -euo pipefail

export JAVA_HOME="/c/Program Files/Java/jdk-17"
export PATH="$JAVA_HOME/bin:$PATH"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
example_dir="$script_dir/example"

target="${1:-android}"

usage() {
  cat <<'EOF'
Usage:
  ./launch [android|ios]

Examples:
  ./launch
  ./launch android
  ./launch ios
EOF
}

case "$target" in
  android)
    echo "Launching Android example..."

    cd "$example_dir"

    if [[ ! -d node_modules ]]; then
      echo "Installing example dependencies..."
      npm install
    fi

    exec npm run android -- --active-arch-only
    ;;

  ios)
    if [[ "$(uname -s)" != "Darwin" ]]; then
      echo "Error: iOS can only be launched from macOS." >&2
      exit 1
    fi

    echo "Launching iOS example..."

    cd "$example_dir"

    if [[ ! -d node_modules ]]; then
      echo "Installing example dependencies..."
      npm install
    fi

    exec npm run ios
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