#!/bin/bash
script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
build_log_file=$script_dir/build.log
test_log_file=$script_dir/test.log
platform=""
if [[ $1 == "android" ]]; then
    platform="apk"
else
    platform="$1"
fi
if [[ $platform == "ios" ]]; then
    platform="ios --simulator"
fi
if [[ -f $build_log_file ]]; then
    rm $build_log_file
fi
touch $build_log_file
echo "Log file created at $build_log_file"
cd $script_dir/flutter

if [[ $* == *"--clean-build"* ]]; then
    rm -rf example/.dart_tool/hooks_runner/shared/ffmpeg_kit_extended_flutter
    rm -rf example/.dart_tool/hooks_runner/ffmpeg_kit_extended_flutter
    rm -rf example/build
elif [[ $* == *"--clean"* ]]; then
    flutter clean
    cd $script_dir/flutter/example
    flutter clean
    cd $script_dir/flutter
fi

flutter pub get && flutter pub upgrade >> $build_log_file 2>&1
cd $script_dir/flutter/example

flutter pub get && flutter pub upgrade >> $build_log_file 2>&1
if [[ $* == *"--ffigen"* ]]; then
    cd $script_dir/flutter
    if [[ ! -f ".dart_tool/ffmpeg_kit_extended_flutter/include/ffmpegkit_wrapper.h" ]]; then
        mkdir -p .dart_tool/ffmpeg_kit_extended_flutter/include
        header_dir=$(find './example/.dart_tool/hooks_runner/shared/ffmpeg_kit_extended_flutter/build/ffmpeg_kit_cache' -name 'include' -type d | head -n 1)
        cp -r "$header_dir" .dart_tool/ffmpeg_kit_extended_flutter/
    fi
    cd $script_dir/flutter && dart run ffigen --config ffigen.yaml && cd example >> $build_log_file 2>&1
fi
if [[ $* == *"-y"* ]]; then
    flutter build -v $platform $2 >> $build_log_file 2>&1 || cd $script_dir
fi
cd $script_dir
if [[ $* == *"--test-api"* ]]; then
    cd $script_dir/flutter
    flutter test test/api_test.dart >> $test_log_file 2>&1 || cd $script_dir
fi
if [[ $* == *"--test-plugin"* ]]; then
    cd $script_dir/flutter/example
    flutter test integration_test/plugin_integration_test.dart >> $test_log_file 2>&1 || cd $script_dir
fi