/**
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

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

import 'generated/ffmpeg_kit_bindings.dart';

DynamicLibrary? _cachedLibrary;

/// Loads the FFmpegKit native library based on the current platform.
///
/// This function is used to load the appropriate library file based on the
/// current platform (Android, iOS/macOS, Windows, or Linux).
DynamicLibrary _loadLibrary() {
  if (_cachedLibrary != null) return _cachedLibrary!;

  // Try default locations
  try {
    if (Platform.isAndroid) {
      _cachedLibrary = DynamicLibrary.open('libffmpegkit.so');
    } else if (Platform.isIOS || Platform.isMacOS) {
      _cachedLibrary = DynamicLibrary.process();
    } else if (Platform.isWindows) {
      _cachedLibrary = DynamicLibrary.open('libffmpegkit.dll');
    } else if (Platform.isLinux) {
      _cachedLibrary = DynamicLibrary.open('libffmpegkit.so');
    }
    return _cachedLibrary!;
  } catch (e) {
    final sep = Platform.isWindows ? '\\' : '/';
    // If not found, try to locate in .dart_tool cache (Common for 'flutter test')
    final cacheRoot = Platform.packageConfig != null
        ? Directory.fromUri(
            Uri.parse(Platform.packageConfig!).resolve("..$sep.."))
        : Directory.current;

    String platformName = Platform.operatingSystem;
    if (Platform.isMacOS) platformName = 'macos';

    print('DEBUG: cacheRoot: ${cacheRoot.path}');
    final pathFile = File(path.join(cacheRoot.path, '.dart_tool',
        'ffmpeg_kit_extended_flutter', platformName, 'current_path.txt'));
    print('DEBUG: pathFile: ${pathFile.path}');

    if (pathFile.existsSync()) {
      final cachedPath = pathFile.readAsStringSync().trim();
      print('DEBUG: cachedPath: $cachedPath');
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
      } else if (Platform.isLinux) {
        if (File(path.join(cachedPath, 'lib', 'libffmpegkit.so'))
            .existsSync()) {
          libPath = path.join(cachedPath, 'lib', 'libffmpegkit.so');
        } else {
          libPath = path.join(cachedPath, 'libffmpegkit.so');
        }
      } else if (Platform.isMacOS) {
        // Usually via Framework or dylib, assume loading by path works
        libPath = path.join(cachedPath, 'lib', 'libffmpegkit.dylib');
      }

      final absoluteLibPath = File(libPath).absolute.path;
      print('DEBUG: Resolved libPath (absolute): $absoluteLibPath');
      print('DEBUG: libPath exists: ${File(absoluteLibPath).existsSync()}');
      print('DEBUG: CWD: ${Directory.current.path}');

      if (Platform.isWindows) {
        final libDir = path.dirname(absoluteLibPath);
        _addDllDirectory(libDir);
      }

      try {
        _cachedLibrary = DynamicLibrary.open(absoluteLibPath);
        return _cachedLibrary!;
      } catch (inner) {
        print('DEBUG: Failed to open library from parsed path: $inner');
        // Try one last fallback with just the name
        try {
          _cachedLibrary = DynamicLibrary.open(path.basename(absoluteLibPath));
          return _cachedLibrary!;
        } catch (_) {}
      }
    } else {
      print('DEBUG: pathFile does not exist');
    }
    throw Exception(e);
  }
}

/// Helper for Windows to add DLL search directory.
/// This ensures that dependencies in the same folder (or MSYS2) are found.
void _addDllDirectory(String dirPath) {
  if (!Platform.isWindows) return;
  try {
    final kernel32 = DynamicLibrary.open('kernel32.dll');

    // AddDllDirectory is preferred over SetDllDirectoryW
    final addDllDirectory = kernel32.lookupFunction<
        Pointer Function(Pointer<Utf16>),
        Pointer Function(Pointer<Utf16>)>('AddDllDirectory');

    // SetDefaultDllDirectories tells the OS to actually look at the paths we add
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
    print('DEBUG: Added to DLL Search Path: $dirPath');
  } catch (e) {
    // Fallback to your existing SetDllDirectoryW if AddDllDirectory isn't available
    print(
        'DEBUG: AddDllDirectory failed, check if Windows 7/8 without KB2533623: $e');
  }
}

/// Returns the [DynamicLibrary] instance for the FFmpegKit native library.
///
/// This getter performs a lazy load of the appropriate library file based on the
/// current platform (Android, iOS/macOS, Windows, or Linux).
DynamicLibrary get ffmpegLibrary => _loadLibrary();

FFmpegKitBindings? _ffmpegInstance;

/// The global [FFmpegKitBindings] instance.
///
/// Accessing this getter will automatically initialize the bindings by loading
/// the native dynamic library if it hasn't been loaded yet.
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
