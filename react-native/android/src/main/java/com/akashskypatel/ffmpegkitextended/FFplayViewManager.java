package com.akashskypatel.ffmpegkitextended;

import androidx.annotation.NonNull;

import com.facebook.react.module.annotations.ReactModule;
import com.facebook.react.uimanager.SimpleViewManager;
import com.facebook.react.uimanager.ThemedReactContext;
import com.facebook.react.uimanager.ViewManagerDelegate;
import com.facebook.react.viewmanagers.FFplayViewManagerDelegate;
import com.facebook.react.viewmanagers.FFplayViewManagerInterface;

@ReactModule(name = FFplayViewManager.REACT_CLASS)
public final class FFplayViewManager
        extends SimpleViewManager<FFplayTextureView>
        implements FFplayViewManagerInterface<FFplayTextureView> {

    public static final String REACT_CLASS = "FFplayView";

    private final ViewManagerDelegate<FFplayTextureView> delegate =
            new FFplayViewManagerDelegate<>(this);

    @Override
    protected ViewManagerDelegate<FFplayTextureView> getDelegate() {
        return delegate;
    }

    @NonNull
    @Override
    public String getName() {
        return REACT_CLASS;
    }

    @NonNull
    @Override
    protected FFplayTextureView createViewInstance(
            @NonNull ThemedReactContext reactContext) {
        return new FFplayTextureView(reactContext);
    }

    @Override
    public void onDropViewInstance(
            @NonNull FFplayTextureView view) {
        view.releaseFFplaySurface();
        super.onDropViewInstance(view);
    }
}