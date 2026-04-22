/*
 * Copyright (c) 2018-2022 Taner Sener
 * Copyright (c) 2025 Akash Patel
 *
 * This file is part of FFmpegKit.
 *
 * FFmpegKit is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * FFmpegKit is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with FFmpegKit.  If not, see <http://www.gnu.org/licenses/>.
 */

// All FFmpegKit / FFprobe / FFplay session APIs are now accessed directly via
// dart:ffi (see ffmpeg_kit_extended.dart).  The only native channel still
// required on iOS/macOS is `ffplay_kit_desktop`, which is handled entirely by
// FfplayKitPlugin.  This file exists only to satisfy GeneratedPluginRegistrant,
// which calls +[FfmpegKitExtendedFlutterPlugin registerWithRegistrar:].

#import "FfmpegKitExtendedFlutterPlugin.h"
#import "FfplayKitPlugin.h"
#include <dlfcn.h>

@implementation FfmpegKitExtendedFlutterPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  // Promote libffmpegkit to RTLD_GLOBAL so Dart FFI can find its symbols
  // via dlsym(RTLD_DEFAULT, ...) / DynamicLibrary.process()
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *libPath =
      [[bundle bundlePath] stringByAppendingPathComponent:
                               @"Versions/A/Frameworks/libffmpegkit.dylib"];
  dlopen([libPath UTF8String], RTLD_GLOBAL | RTLD_NOW);
  [FfplayKitPlugin registerWithRegistrar:registrar];
}

@end
