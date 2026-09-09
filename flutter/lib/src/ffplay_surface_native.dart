/// FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
/// Copyright (C) 2026 Akash Patel
///
/// This library is free software; you can redistribute it and/or
/// modify it under the terms of the GNU Lesser General Public
/// License as published by the Free Software Foundation; either
/// version 2.1 of the License, or (at your option) any later version.
library;

import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

import 'ffplay_android_surface.dart';
import 'ffplay_desktop_texture.dart';

/// Native Flutter texture-backed FFplay video output surface.
///
/// Android uses an `ANativeWindow` surface. Desktop and Apple platforms use
/// the native pixel-buffer texture implementations. Web uses the conditional
/// WebAssembly implementation exported by `ffplay_surface.dart`.
class FFplaySurface {
  final int textureId;

  final FFplayAndroidSurface? _android;
  final FFplayDesktopTexture? _desktop;

  FFplaySurface._({
    required this.textureId,
    FFplayAndroidSurface? android,
    FFplayDesktopTexture? desktop,
  }) : _android = android,
       _desktop = desktop;

  /// Allocates the native surface and wires it to FFplay.
  static Future<FFplaySurface?> create({int width = 1, int height = 1}) async {
    if (Platform.isAndroid) {
      final surface = await FFplayAndroidSurface.create(
        width: width,
        height: height,
      );
      if (surface == null) return null;
      surface.bindToFFplay();
      return FFplaySurface._(textureId: surface.textureId, android: surface);
    }
    if (Platform.isLinux ||
        Platform.isWindows ||
        Platform.isIOS ||
        Platform.isMacOS) {
      final texture = await FFplayDesktopTexture.create();
      if (texture == null) return null;
      return FFplaySurface._(textureId: texture.textureId, desktop: texture);
    }
    return null;
  }

  /// Returns the Flutter widget displaying the native texture.
  Widget toWidget() => Texture(key: ValueKey(textureId), textureId: textureId);

  /// Releases the native texture and stops frame delivery.
  Future<void> release() async {
    await _android?.release();
    await _desktop?.release();
  }
}
