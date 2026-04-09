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

import '../ffmpeg_kit_extended_flutter.dart';
import 'ffmpeg_kit_extended_flutter_loader.dart';

/// Android-specific FFplay utilities.
///
/// Provides Surface binding required for FFplay video output on Android.
/// Because FFplay uses SDL2 in library mode, caller must supply
/// an `ANativeWindow*` pointer before starting playback so SDL can
/// render frames to it.
///
/// ### Typical usage
///
/// From the **Kotlin/Java** side, obtain the native window pointer and pass it
/// to Dart via a method channel or any other mechanism:
///
/// ```kotlin
/// val ptr = FFplayKitAndroid.getNativeWindowPtr(surfaceView.holder.surface)
/// // send ptr to Dart (e.g. MethodChannel)
/// ```
///
/// From **Dart**, before calling [FFplayKit.executeAsync]:
///
/// ```dart
/// // nativeWindowPtr received from Kotlin/Java via platform channel
/// FFplayKitAndroid.setAndroidSurface(nativeWindowPtr);
/// final session = await FFplayKit.executeAsync('ffplay -i input.mp4');
///
/// // When the Surface is destroyed:
/// FFplayKitAndroid.clearAndroidSurface();
/// FFplayKitAndroid.releaseNativeWindowPtr(nativeWindowPtr);
/// ```
///
/// Audio output uses SDL2's OpenSL ES backend and requires no additional setup.
class FFplayKitAndroid {
  /// Tracks the currently bound native window pointer to prevent race conditions
  static int _currentNativeWindowPtr = 0;

  /// Sets Android ANativeWindow for FFplay video output.
  /// [nativeWindowPtr] is the `ANativeWindow*` obtained from
  /// `FFplayKitAndroid.getNativeWindowPtr(surface)` on the Java/Kotlin side,
  /// cast to a Dart [int].
  /// Must be called **before** executing an FFplay session.
  /// No-op on non-Android platforms.
  static void setAndroidSurface(int nativeWindowPtr) {
    if (!Platform.isAndroid) return;
    _currentNativeWindowPtr = nativeWindowPtr;
    FFmpegKitExtended.requireInitialized();
    ffmpeg.ffplay_kit_set_android_surface_ptr(nativeWindowPtr);
  }

  /// Clears Android ANativeWindow, stopping video output.
  /// Call when Surface is destroyed (e.g., in `surfaceDestroyed()`).
  /// After calling this, also call [releaseNativeWindowPtr] with the pointer
  /// obtained from `FFplayKitAndroid.getNativeWindowPtr` to avoid leaking
  /// the native window reference.
  /// No-op on non-Android platforms.
  static void clearAndroidSurface() {
    if (!Platform.isAndroid) return;
    _currentNativeWindowPtr = 0;
    FFmpegKitExtended.requireInitialized();
    ffmpeg.ffplay_kit_clear_android_surface();
  }

  /// Clears Android ANativeWindow only if it matches the specified pointer.
  /// This prevents race conditions where stale surfaces clear the active one.
  /// No-op on non-Android platforms.
  static void clearAndroidSurfaceIfMatches(int nativeWindowPtr) {
    if (!Platform.isAndroid) return;
    if (_currentNativeWindowPtr == nativeWindowPtr) {
      _currentNativeWindowPtr = 0;
      FFmpegKitExtended.requireInitialized();
      ffmpeg.ffplay_kit_clear_android_surface();
    }
  }

  /// Releases the `ANativeWindow` reference acquired by
  /// `FFplayKitAndroid.getNativeWindowPtr(surface)` on the Java/Kotlin side.
  /// [nativeWindowPtr] is the value previously passed to [setAndroidSurface].
  /// Must be called when playback ends or Surface is destroyed —
  /// whichever comes first — to avoid leaking the native window reference.
  /// No-op on non-Android platforms.
  ///
  /// > **Note**: This calls native `releaseNativeWindowPtr` JNI function.
  /// > It is **not** a Dart FFI call — dispatched through existing
  /// > `FFplayKitAndroid` Java class which you must call from Kotlin/Java.
  /// > The Dart method here is documentation only; actual release must
  /// > be triggered from the Kotlin/Java layer.
  static void releaseNativeWindowPtr(int nativeWindowPtr) {
    // Release must be called from the Java/Kotlin side because
    // releaseNativeWindowPtr is a JNI method, not a pure-C export.
    // This method exists as documentation only — see class-level doc.
    throw UnsupportedError(
      'FFplayKitAndroid.releaseNativeWindowPtr must be called from '
      'Kotlin/Java: FFplayKitAndroid.releaseNativeWindowPtr(ptr)',
    );
  }
}
