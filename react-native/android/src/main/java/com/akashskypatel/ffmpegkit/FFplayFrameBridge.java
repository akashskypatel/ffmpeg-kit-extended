package com.akashskypatel.ffmpegkit;

import android.view.Surface;

/**
 * Consumes frozen-ABI FFplay RGBA callbacks and presents them to the React
 * Native TextureView. This class is an internal wrapper implementation.
 */
public final class FFplayFrameBridge {
    static {
        System.loadLibrary("ffmpeg_kit_extended_react_native_android");
    }

    private FFplayFrameBridge() {}

    public static native boolean bindSurface(Surface surface);

    public static native void clearSurface();
}
