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

import 'package:flutter/widgets.dart';

import 'ffplay_android_surface.dart';
import 'ffplay_desktop_texture.dart';

/// Platform-unified FFplay video output surface.
///
/// Wraps [FFplayAndroidSurface] on Android and [FFplayDesktopTexture] on
/// Linux/Windows behind a single API, so callers need no platform checks.
///
/// ### Typical usage
///
/// ```dart
/// // Before starting playback — always create the surface unconditionally:
/// _surface = await FFplaySurface.create();
///
/// final session = await FFplayKit.executeAsync('-i "$path"');
///
/// // Display in the widget tree only when video frames have arrived.
/// // Drive this flag from session.videoSizeStream:
/// if (_hasVideo && _surface != null) ...[
///   AspectRatio(aspectRatio: ar, child: _surface!.toWidget()),
/// ]
///
/// // When done (or on session complete):
/// await _surface?.release();
/// _surface = null;
/// ```
///
/// **Audio-only content** — always call [create] before starting playback.
/// The native layer's `has_video_frames` guard ensures that Flutter's texture
/// system is never given an empty buffer: `copy_pixels` returns `false` until
/// the first decoded video frame arrives.  Because the [Texture] widget is
/// only inserted into the widget tree when `_hasVideo` is true (driven by
/// the video size stream), Flutter never polls the texture for
/// audio-only media and no crash can occur.
///
/// [create] returns `null` on unsupported platforms or if the underlying
/// surface/texture allocation fails.
class FFplaySurface {
  /// Flutter texture ID backing this surface.
  final int textureId;

  final FFplayAndroidSurface? _android;
  final FFplayDesktopTexture? _desktop;

  FFplaySurface._({
    required this.textureId,
    FFplayAndroidSurface? android,
    FFplayDesktopTexture? desktop,
  })  : _android = android,
        _desktop = desktop;

  /// Allocates platform-appropriate video surface and wires it to FFplay.
  /// On Android, creates `SurfaceTexture`-backed `ANativeWindow` and calls
  /// `FFplayAndroidSurface.bindToFFplay` automatically. On Linux/Windows/iOS/
  /// macOS, creates a native pixel-buffer texture and registers the frame
  /// callback via the platform plugin.
  /// Call this unconditionally before starting playback — for audio-only files
  /// the surface is allocated but [Texture] widget is never shown (because
  /// `_hasVideo` from the video size stream stays false), so no
  /// frames are ever requested from the native layer.
  /// [width] and [height] are Android-only hints for initial buffer size;
  /// ignored on other platforms.
  /// Returns `null` on unsupported platforms or on allocation failure.
  static Future<FFplaySurface?> create({int width = 1, int height = 1}) async {
    if (Platform.isAndroid) {
      final s = await FFplayAndroidSurface.create(width: width, height: height);
      if (s == null) return null;
      s.bindToFFplay();
      return FFplaySurface._(textureId: s.textureId, android: s);
    }
    if (Platform.isLinux || Platform.isWindows ||
        Platform.isIOS || Platform.isMacOS) {
      final t = await FFplayDesktopTexture.create();
      if (t == null) return null;
      return FFplaySurface._(textureId: t.textureId, desktop: t);
    }
    return null;
  }

  /// Returns [Widget] that composites current video frame into the tree.
  Widget toWidget() => Texture(textureId: textureId);

  /// Releases native resources and stops frame delivery.
  /// After calling this, discard the [FFplaySurface] instance.
  Future<void> release() async {
    await _android?.release();
    await _desktop?.release();
  }
}
