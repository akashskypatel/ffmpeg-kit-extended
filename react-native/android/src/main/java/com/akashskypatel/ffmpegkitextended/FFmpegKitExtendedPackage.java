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

/** Registers the FFplay Android native view. The TurboModule remains C++ based. */
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
