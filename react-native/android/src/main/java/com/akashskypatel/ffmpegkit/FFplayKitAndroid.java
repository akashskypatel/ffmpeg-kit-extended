/*
 * FFmpegKit React Native Extended - Android FFplay surface bridge
 * Copyright (C) 2026 Akash Patel
 */

package com.akashskypatel.ffmpegkit;

import android.view.Surface;

/**
 * JNI bridge implemented by libffmpegkit.so.
 *
 * <p>The native implementation acquires and owns an ANativeWindow reference
 * for the supplied Surface until another Surface is installed or null is
 * supplied. Audio playback is handled directly by FFplay/SDL and does not
 * require a Surface.</p>
 */
public final class FFplayKitAndroid {
    static {
        System.loadLibrary("ffmpegkit");
    }

    private FFplayKitAndroid() {}

    /** Bind a Surface as FFplay's Android video output, or clear it with null. */
    public static native void setAndroidSurface(Surface surface);

    /** Return an acquired ANativeWindow pointer for callers that need the C API. */
    public static native long getNativeWindowPtr(Surface surface);

    /** Release a pointer returned by getNativeWindowPtr. */
    public static native void releaseNativeWindowPtr(long ptr);
}
