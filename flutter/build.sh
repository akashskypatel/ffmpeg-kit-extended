#!/bin/bash
script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
build_log_file="$script_dir/build.log"
test_log_file="$script_dir/test.log"
platform=""
if [[ $1 == "android" ]]; then
    platform="apk"
else
    platform="$1"
fi
if [[ $platform == "ios" ]]; then
    platform="ios --simulator"
fi
if [[ $platform == "web" ]]; then
    platform="web --wasm"
fi

clean_flutter_outputs() {
    (cd "$script_dir" && flutter clean) || return 1
    (cd "$script_dir/example" && flutter clean) || return 1
    rm -rf -- \
        "$script_dir/.packages" \
        "$script_dir/.flutter-plugins" \
        "$script_dir/.flutter-plugins-dependencies" \
        "$script_dir/example/.packages" \
        "$script_dir/example/.flutter-plugins" \
        "$script_dir/example/.flutter-plugins-dependencies" \
        "$script_dir/android/.dart_tool" \
        "$script_dir/example/android/.dart_tool" \
        "$script_dir/example/ffmpeg_kit_bundle" \
        "$script_dir/example/android/app/mnt" \
        "$script_dir/example/web/assets/packages/ffmpeg_kit_extended_flutter/wasm"
}

clean_flutter_build_caches() {
    clean_flutter_outputs || return 1
    rm -rf -- \
        "$script_dir/.pub" \
        "$script_dir/.pub-cache" \
        "$script_dir/.cache" \
        "$script_dir/.tmp" \
        "$script_dir/coverage" \
        "$script_dir/android/.gradle" \
        "$script_dir/android/.cxx" \
        "$script_dir/android/.externalNativeBuild" \
        "$script_dir/android/app/.gradle" \
        "$script_dir/android/build" \
        "$script_dir/android/app/build" \
        "$script_dir/linux/build" \
        "$script_dir/windows/build" \
        "$script_dir/example/.pub" \
        "$script_dir/example/.pub-cache" \
        "$script_dir/example/.cache" \
        "$script_dir/example/.tmp" \
        "$script_dir/example/.gradle" \
        "$script_dir/example/coverage" \
        "$script_dir/example/test_output" \
        "$script_dir/example/test_audio.mp3" \
        "$script_dir/example/test_video.mp4" \
        "$script_dir/example/.build" \
        "$script_dir/example/.swiftpm" \
        "$script_dir/example/android/.gradle" \
        "$script_dir/example/android/.cxx" \
        "$script_dir/example/android/.externalNativeBuild" \
        "$script_dir/example/android/build" \
        "$script_dir/example/android/app/.gradle" \
        "$script_dir/example/android/app/.cxx" \
        "$script_dir/example/android/app/.externalNativeBuild" \
        "$script_dir/example/android/app/build" \
        "$script_dir/example/ios/Pods" \
        "$script_dir/example/ios/.symlinks" \
        "$script_dir/example/ios/DerivedData" \
        "$script_dir/example/ios/.build" \
        "$script_dir/example/ios/.swiftpm" \
        "$script_dir/example/macos/Pods" \
        "$script_dir/example/macos/.symlinks" \
        "$script_dir/example/macos/DerivedData" \
        "$script_dir/example/macos/.build" \
        "$script_dir/example/macos/.swiftpm" \
        "$script_dir/example/linux/build" \
        "$script_dir/example/windows/build" \
        "$script_dir/example/windows/.vs"
}

if [[ -f $build_log_file ]]; then
    rm -f -- "$build_log_file"
fi
touch "$build_log_file"
echo "Log file created at $build_log_file"
cd "$script_dir"

if [[ $* == *"--clean-build"* ]]; then
    clean_flutter_build_caches || exit 1
elif [[ $* == *"--clean"* ]]; then
    clean_flutter_outputs || exit 1
fi

flutter pub get && flutter pub upgrade >> $build_log_file 2>&1
cd "$script_dir/example"

flutter pub get && flutter pub upgrade >> $build_log_file 2>&1
if [[ $* == *"--ffigen"* ]]; then
    cd "$script_dir"
    if [[ ! -f ".dart_tool/ffmpeg_kit_extended_flutter/include/ffmpegkit_wrapper.h" ]]; then
        mkdir -p .dart_tool/ffmpeg_kit_extended_flutter/include
        header_dir=$(find './example/.dart_tool/hooks_runner/shared/ffmpeg_kit_extended_flutter/build/ffmpeg_kit_cache' -name 'include' -type d | head -n 1)
        cp -r "$header_dir" .dart_tool/ffmpeg_kit_extended_flutter/
    fi
    cd "$script_dir" && dart run ffigen --config ffigen.yaml && cd example >> "$build_log_file" 2>&1
fi
if [[ $* == *"-y"* ]]; then
    flutter build -v $platform "${2:-}" >> "$build_log_file" 2>&1 || cd "$script_dir"
fi
cd "$script_dir"
if [[ $* == *"--test-api"* ]]; then
    cd "$script_dir"
    flutter test test/api_test.dart >> "$test_log_file" 2>&1 || cd "$script_dir"
fi
if [[ $* == *"--test-plugin"* ]]; then
    cd "$script_dir/example"
    flutter test integration_test/plugin_integration_test.dart >> "$test_log_file" 2>&1 || cd "$script_dir"
fi
