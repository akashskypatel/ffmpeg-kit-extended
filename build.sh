#!/bin/bash
script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
build_log_file=$script_dir/build.log
test_log_file=$script_dir/test.log
if [[ -f $build_log_file ]]; then
    rm $build_log_file
fi
touch $build_log_file
echo "Log file created at $build_log_file"
cd $script_dir/flutter
flutter clean && flutter pub get && flutter pub upgrade && dart run ffmpeg_kit_extended_flutter:configure $1 --app-root=. >> $build_log_file 2>&1
cd $script_dir/flutter/example
flutter clean && flutter pub get && flutter pub upgrade && dart run ffmpeg_kit_extended_flutter:configure $1 --app-root=. >> $build_log_file 2>&1
cd $script_dir/flutter && dart run ffigen --config ffigen.yaml && cd example >> $build_log_file 2>&1 
if [[ $* == *"-y"* ]]; then
    flutter build -v $1 $2 >> $build_log_file 2>&1 || cd $script_dir
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