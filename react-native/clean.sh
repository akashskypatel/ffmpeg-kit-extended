#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

echo "Cleaning React Native build artifacts..."

# Library build output
rm -rf \
  lib \
  dist \
  build \
  coverage \
  .metro-cache \
  .tmp

# React Native Codegen
rm -rf \
  android/generated \
  ios/generated

# Library Android / CMake
rm -rf \
  android/.gradle \
  android/.cxx \
  android/.externalNativeBuild \
  android/build

# Library iOS
rm -rf \
  ios/build \
  ios/Pods

# Example caches
rm -rf \
  example/.metro-cache \
  example/.tmp \
  example/coverage

# Example Android / Gradle / CMake
rm -rf \
  example/android/.gradle \
  example/android/.cxx \
  example/android/.externalNativeBuild \
  example/android/build \
  example/android/app/.cxx \
  example/android/app/.externalNativeBuild \
  example/android/app/build

# Example iOS
rm -rf \
  example/ios/build \
  example/ios/Pods

# TypeScript caches, excluding node_modules
find . \
  -path '*/node_modules' -prune -o \
  -type f -name '*.tsbuildinfo' \
  -exec rm -f {} +

echo "Clean complete."
echo
echo "Rebuild the library:"
echo "  npm run prepare"
echo
echo "Rebuild the Android example:"
echo "  cd example"
echo "  npm run android -- --active-arch-only"