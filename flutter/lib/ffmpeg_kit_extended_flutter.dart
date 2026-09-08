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

/// Flutter plugin for FFmpeg, FFprobe, and FFplay commands.
///
/// Native platforms use Dart FFI. Web builds use the bundled Emscripten/WASM
/// runtime while preserving the same public entry points.
library;

export 'src/ffmpeg_kit_extended_flutter_native.dart'
    if (dart.library.js_interop) 'src/web/ffmpeg_kit_extended_flutter_web_api.dart';
