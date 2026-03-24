/// FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
/// Copyright (C) 2026 Akash Patel
///
/// This library is free software; you can redistribute it and/or
/// modify it under the terms of the GNU Lesser General Public
/// License as published by the Free Software Foundation; either
/// version 2.1 of the License, or (at your option) any later version.
///
/// This library is distributed in the hope that it will be useful,
/// but WITHOUT ANY WARRANTY; without even the implied warranty of
/// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
/// Lesser General Public License for more details.
///
/// You should have received a copy of the GNU Lesser General Public
/// License along with this library; if not, write to the Free Software
/// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
library;

import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'ffplay_kit_android.dart';

/// Flutter [Texture]-backed Android surface for FFplay video output.
///
/// Creates native `android.view.Surface` registered with Flutter's
/// `TextureRegistry`, obtains `ANativeWindow*` pointer, and exposes both
/// as a [Widget] (via `toWidget`) and SDL blit target (via `bindToFFplay`).
///
/// ### Typical usage
///
/// ```dart
/// // Before starting playback:
/// _surface = await FFplayAndroidSurface.create();
/// if (_surface != null) _surface!.bindToFFplay();
///
/// final session = await FFplayKit.executeAsync('-i "$path"');
///
/// // Display in the widget tree:
/// _surface?.toWidget()  // use inside AspectRatio / SizedBox
///
/// // When done:
/// await _surface?.release();
/// _surface = null;
/// ```
///
/// On non-Android platforms [create] returns `null` and all other methods
/// are no-ops.
class FFplayAndroidSurface {
  static const _channel = MethodChannel('ffplay_kit_android');

  /// Flutter texture ID — pass to [Texture(textureId: textureId)].
  final int textureId;

  /// Native ANativeWindow* as a Dart int.
  final int nativeWindowPtr;

  FFplayAndroidSurface._({
    required this.textureId,
    required this.nativeWindowPtr,
  });

  /// Allocates new Flutter texture + native `Surface`.
  /// [width] and [height] are optional hints for initial
  /// `SurfaceTexture.setDefaultBufferSize`. Native blit code calls
  /// `ANativeWindow_setBuffersGeometry` each frame, so actual video
  /// dimensions take effect automatically.
  /// Returns `null` on non-Android platforms or if surface creation fails.
  static Future<FFplayAndroidSurface?> create({
    int width = 1,
    int height = 1,
  }) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'createSurface',
        {'width': width, 'height': height},
      );
      if (result == null) return null;
      return FFplayAndroidSurface._(
        textureId: (result['textureId'] as num).toInt(),
        nativeWindowPtr: (result['nativeWindowPtr'] as num).toInt(),
      );
    } on PlatformException {
      return null;
    }
  }

  /// Returns [Widget] that displays this surface in Flutter widget tree.
  Widget toWidget() => Texture(textureId: textureId);

  /// Registers surface as FFplay video output target.
  /// Must be called **before** `FFplayKit.executeAsync`.
  /// No-op on non-Android platforms.
  void bindToFFplay() => FFplayKitAndroid.setAndroidSurface(nativeWindowPtr);

  /// Clears FFplay video output binding and releases native resources.
  /// After calling this, discard the [FFplayAndroidSurface] instance.
  Future<void> release() async {
    if (!Platform.isAndroid) return;
    FFplayKitAndroid.clearAndroidSurface();
    try {
      await _channel.invokeMethod<void>('releaseSurface', {
        'textureId': textureId,
        'nativeWindowPtr': nativeWindowPtr,
      });
    } on PlatformException {
      // Surface may already be released; ignore.
    }
  }
}
