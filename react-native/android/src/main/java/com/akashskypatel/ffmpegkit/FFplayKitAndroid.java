/*
 * FFmpegKit React Native Extended - Android FFplay surface bridge
 * Copyright (C) 2026 Akash Patel
 */

package com.akashskypatel.ffmpegkit;

import android.view.Surface;

/**
 * JNI bridge used internally by the React Native {@code FFplayView}.
 *
 * <p>Application code should render the TypeScript {@code FFplayView} component
 * and control playback through {@code FFplaySession}; it should not call this
 * class directly. The native implementation owns one Android video target at a
 * time. Audio playback is handled by FFplay's audio backend and works without a
 * {@link Surface}.</p>
 */
public final class FFplayKitAndroid {
    static {
        System.loadLibrary("ffmpegkit");
    }

    private FFplayKitAndroid() {}

    /**
     * Installs the surface owned by the currently mounted React Native view.
     * Passing {@code null} detaches video output while leaving audio/session
     * lifecycle under FFplay control.
     */
    public static native void setAndroidSurface(Surface surface);

    /**
     * Returns an acquired native-window pointer for internal C API integration.
     * The pointer must be released with {@link #releaseNativeWindowPtr(long)}.
     */
    public static native long getNativeWindowPtr(Surface surface);

    /** Releases a pointer returned by {@link #getNativeWindowPtr(Surface)}. */
    public static native void releaseNativeWindowPtr(long ptr);
}
