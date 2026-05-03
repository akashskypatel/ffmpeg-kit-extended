/*
 * FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
 * Copyright (C) 2026 Akash Patel
 *
 * This library is free software; you can redistribute it and/or modify it
 * under the terms of the GNU Lesser General Public License as published by the
 * Free Software Foundation; either version 2.1 of the License, or (at your
 * option) any later version.
 *
 * This library is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this library; if not, write to the Free Software Foundation, Inc.,
 * 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#import "include/FfplayKitPlugin.h"

#import <Accelerate/Accelerate.h>
#import <CoreVideo/CoreVideo.h>
#import <Flutter/Flutter.h>
#include <dlfcn.h>

// ─── ffplay C API
// ─────────────────────────────────────────────────────────────
// Non-Android path only; pixel format: RGBA8888, linesize == width * 4.
// See flutter/.dart_tool/ffmpeg_kit_extended_flutter/include/ffplay_lib.h

// Forward declarations of ffplay functions
typedef void (*FFplayFrameCb)(void *userdata, const uint8_t *pixels, int width,
                              int height, int linesize,
                              const char *pixel_format);
typedef void (*FFplayRegisterFrameCallbackFn)(FFplayFrameCb callback,
                                              void *userdata);
static FFplayRegisterFrameCallbackFn _ffplay_kit_register_frame_callback_fn =
    NULL;

static FlutterEventSink sLogEventSink = nil;

@interface FfplayKitLogStreamHandler : NSObject <FlutterStreamHandler>
@end

@implementation FfplayKitLogStreamHandler
- (FlutterError *)onListenWithArguments:(id)arguments
                              eventSink:(FlutterEventSink)eventSink {
  sLogEventSink = [eventSink copy];
  return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
  sLogEventSink = nil;
  return nil;
}
@end

// ─── FfkitPixelTexture
// ────────────────────────────────────────────────────────
//
// Threading model
// ───────────────
// • updateWithPixels: fires from the FFplay executor thread.
//   Copies decoded RGBA pixels into a CVPixelBuffer (with RGBA→BGRA permute
//   via Accelerate), swaps it into _latestBuffer under _lock, then calls
//   onFrameAvailable *outside* the lock.
//
// • copyPixelBuffer fires from Flutter's render thread.
//   Retains _latestBuffer under _lock and returns it; Flutter releases it
//   after the GPU (Metal) upload.

@interface FfkitPixelTexture : NSObject <FlutterTexture>

/// Invoked (outside any lock) after each frame has been written.
/// Wired to -[FlutterTextureRegistry textureFrameAvailable:] by the plugin.
@property(nonatomic, copy) void (^onFrameAvailable)(void);

/// Set to YES by -invalidate; prevents further pixel writes.
@property(nonatomic, assign) BOOL destroyed;

- (void)updateWithPixels:(const uint8_t *)pixels
                   width:(int)width
                  height:(int)height
                linesize:(int)linesize
             pixelFormat:(const char *)pixelFormat;

/// Acquires the lock (draining any in-flight callback), marks destroyed, and
/// releases all CVPixelBuffer resources.
- (void)invalidate;

@end

@implementation FfkitPixelTexture {
  NSLock *_lock;
  CVPixelBufferPoolRef _pool;
  CVPixelBufferRef _latestBuffer;
  int _poolWidth;
  int _poolHeight;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _lock = [[NSLock alloc] init];
    _pool = NULL;
    _latestBuffer = NULL;
    _poolWidth = 0;
    _poolHeight = 0;
    _destroyed = NO;
  }
  return self;
}

static void ffplaykit_log(const char *msg) {
  NSLog(@"FFplayKitPlugin: %s", msg);
  if (sLogEventSink) {
    NSString *message = [NSString stringWithUTF8String:msg];
    NSNumber *timestamp = @([[NSDate date] timeIntervalSince1970] * 1000);
    dispatch_async(dispatch_get_main_queue(), ^{
      FlutterEventSink sink = sLogEventSink;
      if (sink) {
        sink(@{@"message" : message, @"timestamp" : timestamp});
      }
    });
  }
}

/// Creates (or recreates) the CVPixelBufferPool when dimensions change.
/// Must be called while _lock is held.
- (void)_ensurePoolForWidth:(int)w height:(int)h {
  if (_pool && _poolWidth == w && _poolHeight == h)
    return;

  if (_pool) {
    CVPixelBufferPoolRelease(_pool);
    _pool = NULL;
  }
  if (_latestBuffer) {
    CVPixelBufferRelease(_latestBuffer);
    _latestBuffer = NULL;
  }

  // kCVPixelFormatType_32BGRA — the native Metal format on Apple platforms.
  // IOSurface backing ensures GPU accessibility without extra copies.
  NSDictionary *attrs = @{
    (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
    (id)kCVPixelBufferWidthKey : @(w),
    (id)kCVPixelBufferHeightKey : @(h),
    (id)kCVPixelBufferIOSurfacePropertiesKey : @{},
    (id)kCVPixelBufferMetalCompatibilityKey : @YES,
  };
  CVPixelBufferPoolCreate(kCFAllocatorDefault, nil,
                          (__bridge CFDictionaryRef)attrs, &_pool);
  if (!_pool) {
    ffplaykit_log("[ERROR] Failed to create CVPixelBufferPool");
  }
  _poolWidth = w;
  _poolHeight = h;
}

static void getPermuteMapForFormat(const char *fmt, uint8_t map[4]) {
  map[0] = 0;
  map[1] = 1;
  map[2] = 2;
  map[3] = 3;
  if (!fmt)
    return;

  if (strcmp(fmt, "rgb0") == 0) {
    // src: [R][G][B][0] → dst BGRA: [B][G][R][A]
    map[0] = 2;
    map[1] = 1;
    map[2] = 0;
    map[3] = 3;
  } else if (strcmp(fmt, "bgr0") == 0) {
    // src: [B][G][R][0] → dst BGRA: passthrough
    map[0] = 0;
    map[1] = 1;
    map[2] = 2;
    map[3] = 3;
  } else if (strcmp(fmt, "rgba") == 0) {
    // src: [R][G][B][A] → dst BGRA
    map[0] = 2;
    map[1] = 1;
    map[2] = 0;
    map[3] = 3;
  } else if (strcmp(fmt, "bgra") == 0) {
    // src: [B][G][R][A] → dst BGRA: passthrough
    map[0] = 0;
    map[1] = 1;
    map[2] = 2;
    map[3] = 3;
  } else if (strcmp(fmt, "argb") == 0) {
    // src: [A][R][G][B] → dst BGRA
    map[0] = 3;
    map[1] = 2;
    map[2] = 1;
    map[3] = 0;
  } else if (strcmp(fmt, "abgr") == 0) {
    // src: [A][B][G][R] → dst BGRA
    map[0] = 1;
    map[1] = 2;
    map[2] = 3;
    map[3] = 0;
  }
}

- (void)updateWithPixels:(const uint8_t *)pixels
                   width:(int)width
                  height:(int)height
                linesize:(int)linesize
             pixelFormat:(const char *)pixelFormat {
  if (!pixels || width <= 0 || height <= 0) {
    ffplaykit_log("[ERROR] updateWithPixels early return - invalid params");
    return;
  }

  [_lock lock];

  if (_destroyed) {
    [_lock unlock];
    return;
  }

  [self _ensurePoolForWidth:width height:height];

  CVPixelBufferRef newBuf = NULL;
  if (_pool) {
    CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, _pool, &newBuf);
  } else {
    ffplaykit_log("[ERROR] FfplayKitPlugin: Pixel buffer pool is nil");
  }

  if (newBuf) {
    CVPixelBufferLockBaseAddress(newBuf, 0);

    void *dstBase = CVPixelBufferGetBaseAddress(newBuf);
    size_t dstStride = CVPixelBufferGetBytesPerRow(newBuf);

    // RGBA → BGRA via vImage hardware-accelerated channel permute.
    // permuteMap[i] = source channel index for output channel i:
    //   out[0]=B = src[2], out[1]=G = src[1], out[2]=R = src[0], out[3]=A =
    //   src[3]
    vImage_Buffer srcVBuf = {(void *)pixels, (vImagePixelCount)height,
                             (vImagePixelCount)width, (size_t)linesize};
    vImage_Buffer dstVBuf = {dstBase, (vImagePixelCount)height,
                             (vImagePixelCount)width, dstStride};
    uint8_t permuteMap[4];
    getPermuteMapForFormat(pixelFormat, permuteMap);
    vImagePermuteChannels_ARGB8888(&srcVBuf, &dstVBuf, permuteMap,
                                   kvImageNoFlags);
    // For padded formats (rgb0/bgr0) the 4th source byte is always 0x00, so
    // the permuted BGRA buffer has alpha=0 (fully transparent). Fix it up to
    // match the Windows/Linux behavior. Iterate per-row using dstStride to
    // respect any IOSurface row padding.
    if (pixelFormat && (strcmp(pixelFormat, "rgb0") == 0 ||
                        strcmp(pixelFormat, "bgr0") == 0)) {
      uint8_t *row = (uint8_t *)dstBase;
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          row[x * 4 + 3] = 0xFF;
        }
        row += dstStride;
      }
    }
    CVPixelBufferUnlockBaseAddress(newBuf, 0);
    if (_latestBuffer)
      CVPixelBufferRelease(_latestBuffer);
    _latestBuffer =
        newBuf; // +1 refcount from CVPixelBufferPoolCreatePixelBuffer
  } else {
    ffplaykit_log("[ERROR] Failed to create CVPixelBuffer from pool");
  }

  [_lock unlock];

  // Notify Flutter outside the lock to avoid potential deadlock if the
  // render thread calls copyPixelBuffer while we hold _lock.
  void (^cb)(void) = self.onFrameAvailable;
  if (cb)
    cb();
}

/// Called on Flutter's render thread; returns a retained CVPixelBufferRef.
/// Flutter releases it after the Metal texture upload.
- (CVPixelBufferRef)copyPixelBuffer {
  [_lock lock];
  CVPixelBufferRef buf = _latestBuffer;
  if (buf)
    CVPixelBufferRetain(buf);
  [_lock unlock];
  return buf;
}

- (void)invalidate {
  // Acquiring _lock here drains any in-flight updateWithPixels call
  // (which holds _lock for its entire duration), mirroring the mutex-drain
  // pattern used in the Windows/Linux C++ plugins.
  [_lock lock];
  _destroyed = YES;
  if (_latestBuffer) {
    CVPixelBufferRelease(_latestBuffer);
    _latestBuffer = NULL;
  }
  if (_pool) {
    CVPixelBufferPoolRelease(_pool);
    _pool = NULL;
  }
  _poolWidth = 0;
  _poolHeight = 0;
  [_lock unlock];
}

- (void)dealloc {
  [self invalidate];
}

@end

// ─── Static C frame callback (FFplay executor thread) ────────────────────────

static void ffplay_frame_cb(void *userdata, const uint8_t *pixels, int width,
                            int height, int linesize,
                            const char *pixel_format) {
  if (!userdata || !pixels) {
    ffplaykit_log(
        "[ERROR] ffplay_frame_cb early return - userdata or pixels is nil");
    return;
  }
  // __bridge is safe: the object is kept alive by _retainedTexPtr until the
  // callback is unregistered and -releaseTextureState has fully completed.
  FfkitPixelTexture *tex = (__bridge FfkitPixelTexture *)userdata;
  [tex updateWithPixels:pixels
                  width:width
                 height:height
               linesize:linesize
            pixelFormat:pixel_format];
}

// ─── FfplayKitPlugin ─────────────────────────────────────────────────────────

@implementation FfplayKitPlugin {
  NSObject<FlutterTextureRegistry> *_textureRegistry;
  FfkitPixelTexture *_texture;
  int64_t _textureId;
  /// __bridge_retained pointer to _texture, passed as userdata to
  /// ffplay_set_frame_callback.  Balanced by __bridge_transfer in
  /// -releaseTextureState so ARC can reclaim the object.
  void *_retainedTexPtr;
}

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
  _ffplay_kit_register_frame_callback_fn =
      dlsym(RTLD_DEFAULT, "ffplay_kit_register_frame_callback");
  FfplayKitPlugin *instance = [[FfplayKitPlugin alloc] init];
  instance->_textureRegistry = [registrar textures];

  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@"ffplay_kit_desktop"
                                  binaryMessenger:[registrar messenger]];
  [registrar addMethodCallDelegate:instance channel:channel];
  FlutterEventChannel *logChannel =
      [FlutterEventChannel eventChannelWithName:@"ffplay_kit_log"
                                binaryMessenger:[registrar messenger]];
  FfplayKitLogStreamHandler *streamHandler =
      [[FfplayKitLogStreamHandler alloc] init];
  [logChannel setStreamHandler:streamHandler];
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _texture = nil;
    _textureId = -1;
    _retainedTexPtr = nil;
  }
  return self;
}

- (void)handleMethodCall:(FlutterMethodCall *)call
                  result:(FlutterResult)result {
  if ([call.method isEqualToString:@"createTexture"]) {
    [self handleCreateTexture:result];
  } else if ([call.method isEqualToString:@"releaseTexture"]) {
    [self handleReleaseTexture:call result:result];
  } else {
    result(FlutterMethodNotImplemented);
  }
}

- (void)handleCreateTexture:(FlutterResult)result {
  // Release any existing texture before allocating a new one.
  [self releaseTextureState];
  FfkitPixelTexture *tex = [[FfkitPixelTexture alloc] init];
  int64_t tid = [_textureRegistry registerTexture:tex];

  __weak NSObject<FlutterTextureRegistry> *weakReg = _textureRegistry;
  tex.onFrameAvailable = ^{
    [weakReg textureFrameAvailable:tid];
  };

  _texture = tex;
  _textureId = tid;
  // Bump retain count so the object stays alive through the C void* boundary.
  // The matching release happens via __bridge_transfer in -releaseTextureState.
  _retainedTexPtr = (__bridge_retained void *)tex;
  if (_ffplay_kit_register_frame_callback_fn) {
    _ffplay_kit_register_frame_callback_fn(ffplay_frame_cb, _retainedTexPtr);
  } else {
    ffplaykit_log("[ERROR] _ffplay_kit_register_frame_callback_fn is NULL");
  }
  result(@{@"textureId" : @(tid)});
}

- (void)handleReleaseTexture:(FlutterMethodCall *)call
                      result:(FlutterResult)result {
  NSDictionary *args = call.arguments;
  if (![args isKindOfClass:[NSDictionary class]] || args[@"textureId"] == nil) {
    result([FlutterError errorWithCode:@"INVALID_ARGUMENT"
                               message:@"Expected map with textureId"
                               details:nil]);
    return;
  }
  int64_t requestedId = [args[@"textureId"] longLongValue];
  if (_textureId == requestedId) {
    [self releaseTextureState];
  }
  result(nil);
}

- (void)releaseTextureState {
  if (!_texture)
    return;

  // Keep a strong local reference so the object stays alive for the entire
  // duration of this method, even after the ivars are cleared.
  FfkitPixelTexture *tex = _texture;
  _texture = nil;

  // 1. Stop frame delivery.
  if (_ffplay_kit_register_frame_callback_fn) {
    _ffplay_kit_register_frame_callback_fn(NULL, NULL);
  }

  // 2. Drain any in-flight callback: -invalidate acquires _lock, which
  //    guarantees any concurrent updateWithPixels call has fully exited.
  [tex invalidate];

  // 3. Balance the __bridge_retained taken in -handleCreateTexture.
  //    'tex' local still holds a strong ARC ref, so the object is safe.
  if (_retainedTexPtr) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-variable"
    FfkitPixelTexture *tmp =
        (__bridge_transfer FfkitPixelTexture *)_retainedTexPtr;
#pragma clang diagnostic pop
    _retainedTexPtr = nil;
    // 'tmp' goes out of scope → ARC releases the extra retain.
  }

  // 4. Unregister from Flutter's TextureRegistrar.
  if (_textureId >= 0) {
    [_textureRegistry unregisterTexture:_textureId];
    _textureId = -1;
  }

  // 'tex' goes out of scope → ARC releases.
}

- (void)dealloc {
  [self releaseTextureState];
}

@end
