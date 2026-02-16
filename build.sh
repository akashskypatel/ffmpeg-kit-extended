#!/bin/bash
log_file=$(pwd)/build.log
if [[ -f $log_file ]]; then
    rm $log_file
fi
touch $log_file
echo "Log file created at $log_file"
cd flutter
flutter clean >> $log_file 2>&1
flutter pub get >> $log_file 2>&1
cd example
flutter clean >> $log_file 2>&1
flutter pub get >> $log_file 2>&1
# cd ..
# flutter run ffmpeg_kit_extended_flutter:configure $1
# cd example
if [[ $* == *"-y"* ]]; then
    flutter build -v $1 $2 >> $log_file 2>&1 || cd ../..
fi
cd ../..