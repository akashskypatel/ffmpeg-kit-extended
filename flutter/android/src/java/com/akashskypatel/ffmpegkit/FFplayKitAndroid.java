/*
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

package com.akashskypatel.ffmpegkit;

import android.view.Surface;

/**
 * Android-specific FFplay utilities.
 *
 * <p>Provides the Surface binding required for FFplay video output on Android.
 * Because FFplay uses SDL2 in library mode (not as an SDLActivity), the caller
 * must supply an {@link android.view.Surface} before starting playback so SDL
 * can render frames via {@code SDL_CreateWindowFrom(ANativeWindow*)}.
 *
 * <p>Audio output uses SDL2's OpenSL ES backend and requires no additional setup.
 *
 * <h3>Usage</h3>
 * <pre>{@code
 * surfaceView.getHolder().addCallback(new SurfaceHolder.Callback() {
 *     public void surfaceCreated(SurfaceHolder holder) {
 *         FFplayKitAndroid.setAndroidSurface(holder.getSurface());
 *     }
 *     public void surfaceDestroyed(SurfaceHolder holder) {
 *         FFplayKitAndroid.setAndroidSurface(null);
 *     }
 *     public void surfaceChanged(SurfaceHolder holder, int format, int w, int h) {}
 * });
 *
 * // Then start playback:
 * FFplayKit.executeAsync("input.mp4", session -> { ... }, 0);
 * }</pre>
 */
public class FFplayKitAndroid {

    static {
        System.loadLibrary("ffmpegkit");
    }

    /**
     * Sets the {@link Surface} that FFplay will render video into.
     *
     * <p>Must be called before executing an FFplay session. The native layer
     * acquires an {@code ANativeWindow} reference from the provided Surface and
     * holds it for the duration of playback.
     *
     * <p>Call with {@code null} when the Surface is destroyed (e.g., inside
     * {@code SurfaceHolder.Callback.surfaceDestroyed()}) to release the native
     * window reference and avoid use-after-free crashes.
     *
     * @param surface an {@link android.view.Surface} from a {@link android.view.SurfaceView}
     *                or {@link android.graphics.SurfaceTexture}, or {@code null} to clear
     */
    public static native void setAndroidSurface(Surface surface);

    /**
     * Returns the {@code ANativeWindow*} for a Java {@link Surface} as a {@code long}.
     *
     * <p>The returned pointer is suitable for passing to
     * {@code ffplay_kit_set_android_surface_ptr()} via Dart FFI (see
     * {@code FFplayKitAndroid.setAndroidSurface(int)} in the Dart bridge).
     *
     * <p><strong>The caller must call {@link #releaseNativeWindowPtr(long)} with
     * the returned value when playback ends or the Surface is destroyed,
     * whichever comes first.</strong> Failing to do so leaks the native window.
     *
     * @param surface a valid, non-null {@link Surface}
     * @return the {@code ANativeWindow*} cast to {@code long}, or {@code 0} on failure
     */
    public static native long getNativeWindowPtr(Surface surface);

    /**
     * Releases the {@code ANativeWindow} reference acquired by
     * {@link #getNativeWindowPtr(Surface)}.
     *
     * @param ptr the value returned by {@link #getNativeWindowPtr(Surface)}
     */
    public static native void releaseNativeWindowPtr(long ptr);
}
