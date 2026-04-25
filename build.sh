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

if [[ $* == *"--clean"* ]]; then
    flutter clean
fi

flutter pub get && flutter pub upgrade >> $build_log_file 2>&1
cd $script_dir/flutter/example

if [[ $* == *"--clean"* ]]; then
    flutter clean
fi

flutter pub get && flutter pub upgrade >> $build_log_file 2>&1
if [[ $* == *"--ffigen"* ]]; then
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