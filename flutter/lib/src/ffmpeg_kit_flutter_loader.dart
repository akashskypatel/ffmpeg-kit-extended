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

import 'dart:developer';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/cupertino.dart' show WidgetsFlutterBinding;
import 'package:flutter/material.dart' show WidgetsFlutterBinding;
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:path/path.dart' as path;

import 'generated/ffmpeg_kit_bindings.dart';

// Win32 LoadLibraryW signature
typedef LoadLibraryWNative = Pointer Function(Pointer<Utf16> lpLibFileName);
typedef GetLastErrorNative = Uint32 Function();
typedef GetLastErrorC = Uint32 Function();
typedef GetLastErrorDart = int Function();

DynamicLibrary? _cachedLibrary;

bool _initialized = false;

/// Loads the native library and initializes [FFmpegKitBindings].
///
/// Must be called once before using any plugin API, typically from `main()`
/// after [WidgetsFlutterBinding.ensureInitialized].
///
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await FFmpegKitExtended.initialize();
///   runApp(const MyApp());
/// }
/// ```
///
/// Calling this more than once is a no-op.
Future<void> initializeFFmpegKit() async {
  if (_initialized) return;
  if (_initializeFuture != null) {
    await _initializeFuture;
    return;
  }
  _initializeFuture = Future(() {
    final lib = _loadLibrary();
    _ffmpegInstance = FFmpegKitBindings(lib);
    _ffmpegInstance!.ffmpeg_kit_initialize();
    _logBuildStamp(_ffmpegInstance!);
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

Future<void>? _initializeFuture;

bool get isFFmpegKitInitialized => _initialized;

/// Loads the FFmpegKit native library based on the current platform.
DynamicLibrary _loadLibrary() {
  if (_cachedLibrary != null) return _cachedLibrary!;

  // Try default locations
  try {
    if (Platform.isAndroid || Platform.isLinux) {
      _cachedLibrary = DynamicLibrary.open('libffmpegkit.so');
    } else if (Platform.isIOS || Platform.isMacOS) {
      _cachedLibrary = DynamicLibrary.process();
    } else if (Platform.isWindows) {
      _cachedLibrary = DynamicLibrary.open('libffmpegkit.dll');
    }
    return _cachedLibrary!;
  } catch (e, s) {
    final sep = Platform.isWindows ? '\\' : '/';
    // If not found, try to locate in .dart_tool cache (common for 'flutter test')
    final cacheRoot = Platform.packageConfig != null
        ? Directory.fromUri(
            Uri.parse(Platform.packageConfig!).resolve("..$sep.."))
        : Directory.current;

    String platformName = Platform.operatingSystem;
    if (Platform.isMacOS) platformName = 'macos';

    log('DEBUG: cacheRoot: ${cacheRoot.path}');
    final pathFile = File(path.join(cacheRoot.path, '.dart_tool',
        'ffmpeg_kit_extended_flutter', platformName, 'current_path.txt'));
    log('DEBUG: pathFile: ${pathFile.path}');

    if (pathFile.existsSync()) {
      final cachedPath = pathFile.readAsStringSync().trim();
      log('DEBUG: cachedPath: $cachedPath');
      String libPath = cachedPath;

      if (Platform.isWindows) {
        // Binaries often in 'bin' or 'lib' depending on bundle
        if (File(path.join(cachedPath, 'bin', 'libffmpegkit.dll'))
            .existsSync()) {
          libPath = path.join(cachedPath, 'bin', 'libffmpegkit.dll');
        } else if (File(path.join(cachedPath, 'lib', 'libffmpegkit.dll'))
            .existsSync()) {
          libPath = path.join(cachedPath, 'lib', 'libffmpegkit.dll');
        } else {
          libPath = path.join(cachedPath, 'libffmpegkit.dll');
        }
      } else if (Platform.isLinux || Platform.isAndroid) {
        if (File(path.join(cachedPath, 'lib', 'libffmpegkit.so'))
            .existsSync()) {
          libPath = path.join(cachedPath, 'lib', 'libffmpegkit.so');
        } else {
          libPath = path.join(cachedPath, 'libffmpegkit.so');
        }
      } else if (Platform.isMacOS || Platform.isIOS) {
        // Support both raw dylib and macOS Framework structures
        if (File(path.join(cachedPath, 'lib', 'libffmpegkit.dylib'))
            .existsSync()) {
          libPath = path.join(cachedPath, 'lib', 'libffmpegkit.dylib');
        } else if (File(
                path.join(cachedPath, 'ffmpegkit.framework', 'ffmpegkit'))
            .existsSync()) {
          libPath = path.join(cachedPath, 'ffmpegkit.framework', 'ffmpegkit');
        } else {
          libPath = path.join(cachedPath, 'libffmpegkit.dylib');
        }
      }

      final absoluteLibPath = File(libPath).absolute.path;
      log('DEBUG: Resolved libPath (absolute): $absoluteLibPath');
      log('DEBUG: libPath exists: ${File(absoluteLibPath).existsSync()}');
      log('DEBUG: CWD: ${Directory.current.path}');

      if (Platform.isWindows) {
        final libDir = path.dirname(absoluteLibPath);
        _addDllDirectory(libDir);
      }

      try {
        _cachedLibrary = DynamicLibrary.open(absoluteLibPath);
        return _cachedLibrary!;
      } catch (e, s) {
        log('DEBUG: Failed to open library from parsed path: $e stackTrace: $s');
        // Try one last fallback with just the name
        try {
          _cachedLibrary = DynamicLibrary.open(path.basename(absoluteLibPath));
          return _cachedLibrary!;
        } catch (_) {}
      }
    } else {
      log('DEBUG: pathFile does not exist');
    }
    throw Exception('Failed to load ffmpegkit library: $e stackTrace: $s');
  }
}

/// Helper for Windows to add DLL search directory.
/// Ensures dependencies in the same folder (or MSYS2) are found.
void _addDllDirectory(String dirPath) {
  if (!Platform.isWindows) return;
  try {
    final kernel32 = DynamicLibrary.open('kernel32.dll');

    // AddDllDirectory is preferred over SetDllDirectoryW
    final addDllDirectory = kernel32.lookupFunction<
        Pointer Function(Pointer<Utf16>),
        Pointer Function(Pointer<Utf16>)>('AddDllDirectory');

    // SetDefaultDllDirectories tells the OS to look at the paths we add
    final setDefaultDllDirectories =
        kernel32.lookupFunction<Int32 Function(Uint32), int Function(int)>(
            'SetDefaultDllDirectories');

    const loadLibrarySearchDefaultDirs = 0x00001000;
    const loadLibrarySearchUserDirs = 0x00000400;

    setDefaultDllDirectories(
        loadLibrarySearchDefaultDirs | loadLibrarySearchUserDirs);

    final pPath = dirPath.toNativeUtf16();
    addDllDirectory(pPath);
    malloc.free(pPath);
    log('DEBUG: Added to DLL Search Path: $dirPath');
  } catch (e) {
    // Fallback to existing SetDllDirectoryW if AddDllDirectory isn't available
    log('DEBUG: AddDllDirectory failed, check if Windows 7/8 without KB2533623: $e');
  }
}

/// Logs the DLL build stamp and verifies key symbols resolve correctly.
///
/// Runs once at initialization and prints to Flutter debug console via [log].
/// Confirms DLL was loaded, build stamp matches, and critical FFI symbols exist.
void _logBuildStamp(FFmpegKitBindings bindings) {
  try {
    // ffmpeg_kit_get_build_stamp not yet in generated bindings, look up directly
    final lib = ffmpegLibrary;
    try {
      final stampFn = lib.lookupFunction<Pointer<Utf8> Function(),
          Pointer<Utf8> Function()>('ffmpeg_kit_get_build_stamp');
      final stamp = stampFn().toDartString();
      log('[FFmpegKit] DLL build stamp: $stamp');
    } catch (e) {
      log('[FFmpegKit] WARNING: ffmpeg_kit_get_build_stamp not found — '
          'DLL predates this build. Symbol error: $e');
    }

    // Probe the video-dimension symbol that is currently failing at runtime.
    try {
      lib.lookup('ffplay_kit_session_get_video_width');
      log('[FFmpegKit] ffplay_kit_session_get_video_width: OK');
    } catch (e) {
      log('[FFmpegKit] MISSING: ffplay_kit_session_get_video_width — '
          'DLL does not export this symbol. $e');
    }

    // Probe the frame-callback symbols added for desktop texture support.
    for (final sym in [
      'ffplay_kit_register_frame_callback',
      'ffplay_kit_unregister_frame_callback',
    ]) {
      try {
        lib.lookup(sym);
        log('[FFmpegKit] $sym: OK');
      } catch (e) {
        log('[FFmpegKit] MISSING: $sym');
      }
    }
  } catch (e) {
    log('[FFmpegKit] _logBuildStamp error: $e');
  }
}

/// Returns the [DynamicLibrary] instance for the FFmpegKit native library.
///
/// Performs lazy load of appropriate library based on current platform.
DynamicLibrary get ffmpegLibrary => _loadLibrary();

FFmpegKitBindings? _ffmpegInstance;

/// The global [FFmpegKitBindings] instance.
///
/// Accessing this getter automatically initializes bindings by loading
/// the native dynamic library if not already loaded.
FFmpegKitBindings get ffmpeg {
  _ffmpegInstance ??= FFmpegKitBindings(ffmpegLibrary);
  return _ffmpegInstance!;
}

/// Injects a custom [DynamicLibrary] instance.
void setFFmpegLibrary(DynamicLibrary library) {
  _cachedLibrary = library;
}

/// Injects a custom [FFmpegKitBindings] instance.
void setFFmpegKitBindings(FFmpegKitBindings bindings) {
  _ffmpegInstance = bindings;
}
