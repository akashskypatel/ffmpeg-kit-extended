/*
 * FFmpegKit React Native Extended - Android FFplay TextureView
 * Copyright (C) 2026 Akash Patel
 */

package com.akashskypatel.ffmpegkitextended;

import android.graphics.SurfaceTexture;
import android.graphics.drawable.Drawable;
import android.view.Surface;
import android.view.TextureView;

import com.akashskypatel.ffmpegkit.FFplayKitAndroid;
import com.facebook.react.uimanager.ThemedReactContext;

import java.lang.ref.WeakReference;

/**
 * TextureView whose Surface is bound to FFplay's global Android video target.
 *
 * <p>FFplayKit currently supports one active Android video output surface at a
 * time. The most recently available FFplayTextureView becomes the owner. A
 * stale view is therefore prevented from clearing a newer view's surface when
 * React Native unmounts or recycles it.</p>
 */
final class FFplayTextureView extends TextureView implements TextureView.SurfaceTextureListener {
    private static final Object SURFACE_LOCK = new Object();
    private static WeakReference<FFplayTextureView> activeOwner = new WeakReference<>(null);

    private Surface surface;

    FFplayTextureView(ThemedReactContext context) {
        super(context);
        setOpaque(true);
        setSurfaceTextureListener(this);

        // A TextureView may already have an available SurfaceTexture when it is
        // reattached/recycled. Bind immediately in that case.
        if (isAvailable() && getSurfaceTexture() != null) {
            bindSurface(getSurfaceTexture());
        }
    }

    /**
     * TextureView rejects background drawables. React Native may apply a
     * background while resolving ViewProps/style, so ignore those calls and
     * let callers put any desired background on a parent View instead.
     */
    @Override
    public void setBackgroundColor(int color) {
        // Intentionally ignored.
    }

    @Override
    public void setBackground(Drawable background) {
        // Intentionally ignored.
    }

    @SuppressWarnings("deprecation")
    @Override
    public void setBackgroundDrawable(Drawable background) {
        // Intentionally ignored.
    }

    private void bindSurface(SurfaceTexture surfaceTexture) {
        releaseJavaSurfaceOnly();

        Surface nextSurface = new Surface(surfaceTexture);
        if (!nextSurface.isValid()) {
            nextSurface.release();
            return;
        }

        synchronized (SURFACE_LOCK) {
            activeOwner = new WeakReference<>(this);
            surface = nextSurface;
            FFplayKitAndroid.setAndroidSurface(surface);
        }
    }

    /** Clear the native FFplay target only when this view still owns it. */
    void releaseFFplaySurface() {
        synchronized (SURFACE_LOCK) {
            FFplayTextureView owner = activeOwner.get();
            if (owner == this) {
                FFplayKitAndroid.setAndroidSurface(null);
                activeOwner.clear();
            }
        }
        releaseJavaSurfaceOnly();
    }

    private void releaseJavaSurfaceOnly() {
        Surface current = surface;
        surface = null;
        if (current != null) {
            current.release();
        }
    }

    @Override
    public void onSurfaceTextureAvailable(SurfaceTexture surfaceTexture, int width, int height) {
        bindSurface(surfaceTexture);
    }

    @Override
    public void onSurfaceTextureSizeChanged(SurfaceTexture surfaceTexture, int width, int height) {
        // FFplay/SDL configures the ANativeWindow buffer geometry for decoded
        // frames. React Native controls the TextureView's displayed size.
    }

    @Override
    public boolean onSurfaceTextureDestroyed(SurfaceTexture surfaceTexture) {
        releaseFFplaySurface();
        return true;
    }

    @Override
    public void onSurfaceTextureUpdated(SurfaceTexture surfaceTexture) {
        // No-op. Frames are written directly by FFplay to the ANativeWindow.
    }

    @Override
    protected void onAttachedToWindow() {
        super.onAttachedToWindow();
        if (isAvailable() && getSurfaceTexture() != null && surface == null) {
            bindSurface(getSurfaceTexture());
        }
    }

    @Override
    protected void onDetachedFromWindow() {
        releaseFFplaySurface();
        super.onDetachedFromWindow();
    }
}
