/*
 * FFmpegKit React Native Extended - Android package registration
 * Copyright (C) 2026 Akash Patel
 */

package com.akashskypatel.ffmpegkitextended;

import com.facebook.react.ReactPackage;
import com.facebook.react.bridge.NativeModule;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.uimanager.ViewManager;

import java.util.Collections;
import java.util.List;

/**
 * Registers Android integration for the package.
 *
 * <p>React Native autolinking creates this package. End users do not instantiate
 * it manually. The package contributes the {@code FFplayView} native component;
 * FFmpeg/FFprobe/FFplay commands are exposed by the C++ TurboModule registered
 * through React Native Codegen.</p>
 */
public final class FFmpegKitExtendedPackage implements ReactPackage {
    @Override
    public List<NativeModule> createNativeModules(ReactApplicationContext reactContext) {
        return Collections.emptyList();
    }

    @Override
    @SuppressWarnings("rawtypes")
    public List<ViewManager> createViewManagers(ReactApplicationContext reactContext) {
        return Collections.singletonList(new FFplayViewManager());
    }
}
