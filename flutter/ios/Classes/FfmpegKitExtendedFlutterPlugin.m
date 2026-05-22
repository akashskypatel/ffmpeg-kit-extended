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

static NSString *const kFFmpegKitCompanionAssetsDir =
    @"Frameworks/App.framework/flutter_assets/packages/ffmpeg_kit_extended_flutter/native";

static NSArray<NSString *> *FFmpegKitCompanionDirectoryCandidates(NSBundle *mainBundle) {
  NSMutableArray<NSString *> *directories = [NSMutableArray array];
  [directories addObject:[[mainBundle bundlePath]
                             stringByAppendingPathComponent:kFFmpegKitCompanionAssetsDir]];
  NSString *privateFrameworksPath = [mainBundle privateFrameworksPath];
  if (privateFrameworksPath.length > 0) {
    [directories addObject:[privateFrameworksPath
                               stringByAppendingPathComponent:
                                   @"App.framework/flutter_assets/packages/ffmpeg_kit_extended_flutter/native"]];
  }
  return directories;
}

static void FFmpegKitPreloadLibrariesAtDirectory(NSString *directoryPath) {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  NSArray<NSString *> *entries = [fileManager contentsOfDirectoryAtPath:directoryPath error:nil];
  if (entries.count == 0) {
    return;
  }

  NSMutableArray<NSString *> *pendingLibraries = [NSMutableArray array];
  for (NSString *entry in entries) {
    if ([entry.pathExtension isEqualToString:@"dylib"]) {
      [pendingLibraries addObject:[directoryPath stringByAppendingPathComponent:entry]];
    }
  }

  [pendingLibraries sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];

  while (pendingLibraries.count > 0) {
    BOOL loadedAnyLibrary = NO;
    NSArray<NSString *> *snapshot = [pendingLibraries copy];
    for (NSString *libraryPath in snapshot) {
      void *handle = dlopen([libraryPath UTF8String], RTLD_GLOBAL | RTLD_NOW);
      if (handle) {
        NSLog(@"[FFmpegKit] Preloaded companion library: %@", libraryPath);
        [pendingLibraries removeObject:libraryPath];
        loadedAnyLibrary = YES;
      }
    }

    if (!loadedAnyLibrary) {
      for (NSString *libraryPath in pendingLibraries) {
        NSLog(@"[FFmpegKit] Failed to preload companion library %@: %s",
              libraryPath, dlerror());
      }
      break;
    }
  }
}

@implementation FfmpegKitExtendedFlutterPlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  // Promote libffmpegkit to RTLD_GLOBAL so Dart FFI and plugin-side dlsym
  // calls can resolve its symbols through RTLD_DEFAULT.
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSBundle *mainBundle = [NSBundle mainBundle];
  
  NSMutableArray<NSString *> *candidatePaths = [NSMutableArray arrayWithArray:@[
    [[bundle bundlePath] stringByAppendingPathComponent:@"Frameworks/ffmpegkit.framework/ffmpegkit"],
    [[bundle bundlePath] stringByAppendingPathComponent:@"Frameworks/libffmpegkit.dylib"],
    [[bundle bundlePath] stringByAppendingPathComponent:@"ffmpegkit.framework/ffmpegkit"],
    [[bundle bundlePath] stringByAppendingPathComponent:@"libffmpegkit.dylib"],
    [[[bundle bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"libffmpegkit.dylib"],
    // Native assets location on iOS
    [[mainBundle bundlePath] stringByAppendingPathComponent:@"Frameworks/ffmpegkit.framework/ffmpegkit"],
    [[mainBundle bundlePath] stringByAppendingPathComponent:@"Frameworks/libffmpegkit.dylib"],
    // Native assets location on macOS
    [[mainBundle bundlePath] stringByAppendingPathComponent:@"Contents/Frameworks/ffmpegkit.framework/ffmpegkit"],
    [[mainBundle bundlePath] stringByAppendingPathComponent:@"Contents/Frameworks/libffmpegkit.dylib"],
  ]];

  for (NSString *companionDirectory in FFmpegKitCompanionDirectoryCandidates(mainBundle)) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:companionDirectory]) {
      FFmpegKitPreloadLibrariesAtDirectory(companionDirectory);
    }
  }

  for (NSString *candidatePath in candidatePaths) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:candidatePath]) {
      void* handle = dlopen([candidatePath UTF8String], RTLD_GLOBAL | RTLD_NOW);
      if (handle) {
        NSLog(@"[FFmpegKit] Successfully preloaded: %@", candidatePath);
        break;
      } else {
        NSLog(@"[FFmpegKit] dlopen failed for %@: %s", candidatePath, dlerror());
      }
    }
  }

  [FfplayKitPlugin registerWithRegistrar:registrar];
}

@end
