#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
architecture="${1:-$(uname -m)}"
destination="${2:-}"
version="${FFMPEG_KIT_VERSION:-0.10.5}"

case "$architecture" in
  x86_64|amd64) architecture="x86_64" ;;
  arm64|aarch64) architecture="arm64" ;;
  *)
    echo "Unsupported Linux architecture: $architecture" >&2
    exit 1
    ;;
esac

artifact="bundle-base-linux-${architecture}-shared-small-lgpl"
tag="v${version}-linux"
url="https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download/${tag}/${artifact}.zip"
cache_root="$repo_root/vendor/linux/$architecture/$version"
archive="$cache_root/${artifact}.zip"
extract_root="$cache_root/$artifact"
marker="$extract_root/.extract_complete"

mkdir -p "$cache_root"

if [[ ! -f "$marker" ]]; then
  if [[ ! -f "$archive" ]]; then
    echo "Downloading FFmpegKit Extended Linux runtime: $artifact" >&2
    curl -fL "$url" -o "$archive"
  fi

  rm -rf "$extract_root"
  mkdir -p "$extract_root"
  echo "Extracting FFmpegKit Extended Linux runtime..." >&2
  unzip -oq "$archive" -d "$extract_root"
  touch "$marker"
fi

mapfile -d '' libraries < <(find "$extract_root" \( -type f -o -type l \) -name '*.so*' -print0 | sort -z)
if [[ ${#libraries[@]} -eq 0 ]]; then
  echo "No Linux shared libraries were found in $archive" >&2
  exit 1
fi

main_library=""
for library in "${libraries[@]}"; do
  if [[ "$(basename "$library")" == "libffmpegkit.so" ]]; then
    main_library="$library"
    break
  fi
done

if [[ -z "$main_library" ]]; then
  echo "libffmpegkit.so was not found in $archive" >&2
  exit 1
fi

if [[ -n "$destination" ]]; then
  mkdir -p "$destination"
  for library in "${libraries[@]}"; do
    target="$destination/$(basename "$library")"
    rm -f "$target"
    cp -Lf "$library" "$target"
  done
fi

printf '%s\n' "$extract_root"
