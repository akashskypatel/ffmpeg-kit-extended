/*
 * FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
 * Copyright (C) 2026 Akash Patel
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

import 'dart:async';
import 'dart:developer';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'generated/ffmpeg_kit_bindings.dart' as ffmpeg;

bool _initialized = false;
Future<void>? _initializeFuture;

/// Global pointer to the native release function, used by [NativeFinalizer].
Pointer<NativeFunction<Void Function(Pointer<Void>)>>? ffmpegKitHandleReleasePtr;

/// Initializes the FFmpegKit native library.
///
/// Must be called once before using any plugin API, typically from `main()`
/// after `WidgetsFlutterBinding.ensureInitialized()`.
///
/// Calling this more than once is a no-op.
Future<void> initializeFFmpegKit() async {
  if (_initialized) return;
  if (_initializeFuture != null) {
    await _initializeFuture;
    return;
  }
  _initializeFuture = Future(() {
    _resolveNativeSymbols();
    ffmpeg.ffmpeg_kit_initialize();
    _logBuildStamp();
  });
  try {
    await _initializeFuture;
    _initialized = true;
  } catch (e, s) {
    log('Failed to initialize FFmpegKit: $e', stackTrace: s);
    _initializeFuture = null;
    rethrow;
  }
}

bool get isFFmpegKitInitialized => _initialized;

/// Resolves raw native symbols that cannot be accessed via @Native bindings
/// (e.g. function pointers for NativeFinalizer).
void _resolveNativeSymbols() {
  try {
    final candidates = <DynamicLibrary Function()>[];
    if (Platform.isAndroid || Platform.isLinux) {
      candidates.add(() => DynamicLibrary.open('libffmpegkit.so'));
    } else if (Platform.isIOS || Platform.isMacOS) {
      candidates.add(DynamicLibrary.process);
      candidates.add(() => DynamicLibrary.open('ffmpegkit.framework/ffmpegkit'));
    } else if (Platform.isWindows) {
      candidates.add(() => DynamicLibrary.open('libffmpegkit.dll'));
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    Object? lastError;
    for (final openLibrary in candidates) {
      try {
        final lib = openLibrary();
        ffmpegKitHandleReleasePtr = lib.lookup('ffmpeg_kit_handle_release');
        return;
      } catch (e) {
        lastError = e;
      }
    }

    if (lastError != null) {
      throw lastError;
    }
  } catch (e) {
    log('[FFmpegKit] Error resolving native symbols: $e');
  }
}

/// Logs the library build stamp and verifies key symbols.
void _logBuildStamp() {
  try {
    final stampPtr = ffmpeg.ffmpeg_kit_get_build_stamp();
    log(
      '[FFmpegKit] Native library initialized. FFmpegKit version: ${stampPtr.cast<Utf8>().toDartString()}',
    );
  } catch (e) {
    log('[FFmpegKit] _logBuildStamp error: $e');
  }
}
