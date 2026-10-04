package com.akashskypatel.ffmpeg_kit_extended_flutter

import android.view.Surface

/**
 * Consumes frozen-ABI FFplay RGBA callbacks and presents them to Flutter's
 * Android SurfaceTexture. This class is an internal wrapper implementation.
 */
internal object FFplayFrameBridge {
    init {
        System.loadLibrary("ffmpeg_kit_extended_flutter_android")
    }

    @JvmStatic
    external fun bindSurface(surface: Surface): Boolean

    @JvmStatic
    external fun clearSurface()
}
