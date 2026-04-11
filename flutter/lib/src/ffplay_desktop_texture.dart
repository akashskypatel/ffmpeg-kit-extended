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

/// Flutter [Texture]-backed desktop surface for FFplay video output.
///
/// On Linux and Windows, FFplay renders frames with SDL2 software renderer.
/// After each `video_refresh` the C++ platform plugin receives decoded pixels
/// through `ffplay_kit_register_frame_callback`, copies them into a
/// `FlutterDesktopPixelBuffer`, and signals Flutter to repaint via
/// `MarkTextureFrameAvailable`. The `Texture` widget composites the
/// current frame into the widget tree.
///
/// ### Typical usage
///
/// ```dart
/// // Before starting playback:
/// _texture = await FFplayDesktopTexture.create();
///
/// final session = await FFplayKit.executeAsync('-i "$path"');
///
/// // Display in the widget tree:
/// _texture?.toWidget()  // use inside AspectRatio / SizedBox
///
/// // When done:
/// await _texture?.release();
/// _texture = null;
/// ```
///
/// On Android, [create] returns `null` and all other methods are no-ops.
///
/// ### API symmetry with `FFplayAndroidSurface`
///
/// Both classes expose `create`, `bindToFFplay`, `toWidget`, and `release`.
/// On desktop, `bindToFFplay` is a no-op because the C++ plugin registers the
/// frame callback automatically when `create` is called.
class FFplayDesktopTexture {
  static const _channel = MethodChannel('ffplay_kit_desktop');

  /// Flutter texture ID — pass to `Texture(textureId: textureId)`.
  final int textureId;

  FFplayDesktopTexture._({required this.textureId});

  /// Allocates Flutter [Texture] backed by native pixel buffer.
  /// Internally the native plugin:
  ///   1. Registers pixel-buffer texture with Flutter's `TextureRegistrar`.
  ///   2. Calls `ffplay_set_frame_callback` so every decoded video frame is
  ///      delivered to this texture automatically.
  /// Calling `create` while previous texture is active implicitly releases
  /// that texture first (native side replaces global frame callback).
  /// Returns `null` on Android or if texture creation fails.
  static Future<FFplayDesktopTexture?> create() async {
    if (!Platform.isLinux && !Platform.isWindows &&
        !Platform.isIOS && !Platform.isMacOS) return null;
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'createTexture',
      );
      if (result == null) return null;
      return FFplayDesktopTexture._(
        textureId: (result['textureId'] as num).toInt(),
      );
    } on PlatformException {
      return null;
    }
  }

  /// Returns [Widget] that displays this texture in Flutter widget tree.
  Widget toWidget() => Texture(textureId: textureId);

  /// No-op on desktop — frame callback is wired by C++ plugin when `create` is called.
  /// Provided for API symmetry with `FFplayAndroidSurface` so callers can write
  /// platform-agnostic setup code.
  void bindToFFplay() {}

  /// Releases native pixel-buffer texture and stops frame delivery.
  /// The native plugin calls `ffplay_set_frame_callback(null, null)` before
  /// unregistering the texture with `TextureRegistrar`.
  /// After calling this, discard the [FFplayDesktopTexture] instance.
  Future<void> release() async {
    if (!Platform.isLinux && !Platform.isWindows &&
        !Platform.isIOS && !Platform.isMacOS) return;
    try {
      await _channel.invokeMethod<void>('releaseTexture', {
        'textureId': textureId,
      });
    } on PlatformException {
      // Texture may already be released; ignore.
    }
  }
}
