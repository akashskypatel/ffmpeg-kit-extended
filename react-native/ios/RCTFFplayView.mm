#import "RCTFFplayView.h"

#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <QuartzCore/QuartzCore.h>
#import <react/renderer/components/FFmpegKitExtendedSpec/ComponentDescriptors.h>
#import <react/renderer/components/FFmpegKitExtendedSpec/RCTComponentViewHelpers.h>

#include <dlfcn.h>
#include <stdint.h>
#include <string.h>

using namespace facebook::react;

typedef void (*FFplayKitFrameCallback)(void *userdata,
                                       const uint8_t *pixels,
                                       int width,
                                       int height,
                                       int linesize,
                                       const char *pixelFormat);
typedef void (*FFplayRegisterFrameCallbackFn)(FFplayKitFrameCallback callback,
                                              void *userdata);
typedef void (*FFplayUnregisterFrameCallbackFn)(void);

@class RCTFFplayView;

@interface FFplayFrameCoordinator : NSObject
@property(nonatomic, weak, nullable) RCTFFplayView *view;
@end

@implementation FFplayFrameCoordinator
@end

static FFplayRegisterFrameCallbackFn gRegisterFrameCallback = NULL;
static FFplayUnregisterFrameCallbackFn gUnregisterFrameCallback = NULL;
static void *gFFmpegKitHandle = NULL;

static FFplayFrameCoordinator *FFplayCoordinator(void) {
  static FFplayFrameCoordinator *coordinator;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    coordinator = [[FFplayFrameCoordinator alloc] init];
  });
  return coordinator;
}

static void ResolveFFplayFrameSymbols(void) {
  if (gRegisterFrameCallback && gUnregisterFrameCallback) {
    return;
  }

  gRegisterFrameCallback = (FFplayRegisterFrameCallbackFn)dlsym(
      RTLD_DEFAULT, "ffplay_kit_register_frame_callback");
  gUnregisterFrameCallback = (FFplayUnregisterFrameCallbackFn)dlsym(
      RTLD_DEFAULT, "ffplay_kit_unregister_frame_callback");

  if (gRegisterFrameCallback && gUnregisterFrameCallback) {
    return;
  }

  if (!gFFmpegKitHandle) {
    gFFmpegKitHandle =
        dlopen("@rpath/ffmpegkit.framework/ffmpegkit", RTLD_NOW | RTLD_LOCAL);
    if (!gFFmpegKitHandle) {
      gFFmpegKitHandle =
          dlopen("ffmpegkit.framework/ffmpegkit", RTLD_NOW | RTLD_LOCAL);
    }
  }

  if (gFFmpegKitHandle) {
    if (!gRegisterFrameCallback) {
      gRegisterFrameCallback = (FFplayRegisterFrameCallbackFn)dlsym(
          gFFmpegKitHandle, "ffplay_kit_register_frame_callback");
    }
    if (!gUnregisterFrameCallback) {
      gUnregisterFrameCallback = (FFplayUnregisterFrameCallbackFn)dlsym(
          gFFmpegKitHandle, "ffplay_kit_unregister_frame_callback");
    }
  }
}

static void FillPermuteMap(const char *pixelFormat, uint8_t map[4]) {
  map[0] = 0;
  map[1] = 1;
  map[2] = 2;
  map[3] = 3;

  if (!pixelFormat) {
    return;
  }

  if (strcmp(pixelFormat, "rgb0") == 0 ||
      strcmp(pixelFormat, "rgba") == 0) {
    map[0] = 2;
    map[1] = 1;
    map[2] = 0;
    map[3] = 3;
  } else if (strcmp(pixelFormat, "bgr0") == 0 ||
             strcmp(pixelFormat, "bgra") == 0) {
    map[0] = 0;
    map[1] = 1;
    map[2] = 2;
    map[3] = 3;
  } else if (strcmp(pixelFormat, "argb") == 0) {
    map[0] = 3;
    map[1] = 2;
    map[2] = 1;
    map[3] = 0;
  } else if (strcmp(pixelFormat, "abgr") == 0) {
    map[0] = 1;
    map[1] = 2;
    map[2] = 3;
    map[3] = 0;
  }
}

@interface RCTFFplayView () <RCTFFplayViewViewProtocol>
- (void)activateFrameOutput;
- (void)deactivateFrameOutput;
- (void)resetFrameState;
- (BOOL)ensurePixelBufferPoolLockedForWidth:(int)width height:(int)height;
- (void)consumeFramePixels:(const uint8_t *)pixels
                     width:(int)width
                    height:(int)height
                  linesize:(int)linesize
               pixelFormat:(const char *)pixelFormat;
- (void)displayPendingFrame;
@end

static void FFplayFrameCallback(void *userdata,
                                const uint8_t *pixels,
                                int width,
                                int height,
                                int linesize,
                                const char *pixelFormat) {
  if (!userdata || !pixels || width <= 0 || height <= 0) {
    return;
  }

  @autoreleasepool {
    FFplayFrameCoordinator *coordinator =
        (__bridge FFplayFrameCoordinator *)userdata;
    RCTFFplayView *view = coordinator.view;
    if (!view) {
      return;
    }

    [view consumeFramePixels:pixels
                       width:width
                      height:height
                    linesize:linesize
                 pixelFormat:pixelFormat];
  }
}

@implementation RCTFFplayView {
  AVSampleBufferDisplayLayer *_displayLayer;
  NSLock *_frameLock;
  CVPixelBufferPoolRef _pixelBufferPool;
  CMVideoFormatDescriptionRef _formatDescription;
  CMSampleBufferRef _pendingSampleBuffer;
  int _poolWidth;
  int _poolHeight;
  BOOL _displayDispatchPending;
  BOOL _acceptFrames;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _frameLock = [[NSLock alloc] init];
    _pixelBufferPool = NULL;
    _formatDescription = NULL;
    _pendingSampleBuffer = NULL;
    _poolWidth = 0;
    _poolHeight = 0;
    _displayDispatchPending = NO;
    _acceptFrames = NO;

    _displayLayer = [AVSampleBufferDisplayLayer layer];
    _displayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    _displayLayer.backgroundColor = UIColor.blackColor.CGColor;
    [self.layer addSublayer:_displayLayer];
  }
  return self;
}

+ (ComponentDescriptorProvider)componentDescriptorProvider {
  return concreteComponentDescriptorProvider<FFplayViewComponentDescriptor>();
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _displayLayer.frame = self.bounds;
}

- (void)didMoveToWindow {
  [super didMoveToWindow];
  if (self.window) {
    [self activateFrameOutput];
  } else {
    [self deactivateFrameOutput];
  }
}

- (void)prepareForRecycle {
  [self deactivateFrameOutput];
  [self resetFrameState];
  [super prepareForRecycle];
}

- (void)dealloc {
  [self deactivateFrameOutput];
  [self resetFrameState];
}

- (void)activateFrameOutput {
  ResolveFFplayFrameSymbols();
  if (!gRegisterFrameCallback) {
    NSLog(@"FFmpegKitExtended: ffplay_kit_register_frame_callback was not found");
    return;
  }

  FFplayFrameCoordinator *coordinator = FFplayCoordinator();
  @synchronized(coordinator) {
    if (coordinator.view == self && _acceptFrames) {
      return;
    }

    if (gUnregisterFrameCallback) {
      gUnregisterFrameCallback();
    }

    coordinator.view = self;
    [_frameLock lock];
    _acceptFrames = YES;
    [_frameLock unlock];

    gRegisterFrameCallback(FFplayFrameCallback, (__bridge void *)coordinator);
  }
}

- (void)deactivateFrameOutput {
  FFplayFrameCoordinator *coordinator = FFplayCoordinator();
  @synchronized(coordinator) {
    if (coordinator.view != self) {
      return;
    }

    if (gUnregisterFrameCallback) {
      // ffplay_set_frame_callback(NULL, NULL) drains any in-flight callback
      // before returning, so it is safe to detach this view afterward.
      gUnregisterFrameCallback();
    }

    coordinator.view = nil;
    [_frameLock lock];
    _acceptFrames = NO;
    [_frameLock unlock];
  }
}

- (void)resetFrameState {
  [_frameLock lock];
  _acceptFrames = NO;
  _displayDispatchPending = NO;

  if (_pendingSampleBuffer) {
    CFRelease(_pendingSampleBuffer);
    _pendingSampleBuffer = NULL;
  }
  if (_formatDescription) {
    CFRelease(_formatDescription);
    _formatDescription = NULL;
  }
  if (_pixelBufferPool) {
    CVPixelBufferPoolRelease(_pixelBufferPool);
    _pixelBufferPool = NULL;
  }
  _poolWidth = 0;
  _poolHeight = 0;
  [_frameLock unlock];

  if ([NSThread isMainThread]) {
    [_displayLayer flushAndRemoveImage];
  } else {
    __weak AVSampleBufferDisplayLayer *weakLayer = _displayLayer;
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakLayer flushAndRemoveImage];
    });
  }
}

- (BOOL)ensurePixelBufferPoolLockedForWidth:(int)width height:(int)height {
  if (_pixelBufferPool && _poolWidth == width && _poolHeight == height) {
    return YES;
  }

  if (_pendingSampleBuffer) {
    CFRelease(_pendingSampleBuffer);
    _pendingSampleBuffer = NULL;
  }
  if (_formatDescription) {
    CFRelease(_formatDescription);
    _formatDescription = NULL;
  }
  if (_pixelBufferPool) {
    CVPixelBufferPoolRelease(_pixelBufferPool);
    _pixelBufferPool = NULL;
  }

  NSDictionary *attributes = @{
    (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
    (id)kCVPixelBufferWidthKey : @(width),
    (id)kCVPixelBufferHeightKey : @(height),
    (id)kCVPixelBufferIOSurfacePropertiesKey : @{},
    (id)kCVPixelBufferMetalCompatibilityKey : @YES,
  };

  CVReturn result = CVPixelBufferPoolCreate(
      kCFAllocatorDefault,
      NULL,
      (__bridge CFDictionaryRef)attributes,
      &_pixelBufferPool);
  if (result != kCVReturnSuccess || !_pixelBufferPool) {
    _pixelBufferPool = NULL;
    return NO;
  }

  _poolWidth = width;
  _poolHeight = height;
  return YES;
}

- (void)consumeFramePixels:(const uint8_t *)pixels
                     width:(int)width
                    height:(int)height
                  linesize:(int)linesize
               pixelFormat:(const char *)pixelFormat {
  if (!pixels || width <= 0 || height <= 0 || linesize <= 0) {
    return;
  }

  [_frameLock lock];
  if (!_acceptFrames ||
      ![self ensurePixelBufferPoolLockedForWidth:width height:height]) {
    [_frameLock unlock];
    return;
  }

  CVPixelBufferRef pixelBuffer = NULL;
  CVReturn poolResult = CVPixelBufferPoolCreatePixelBuffer(
      kCFAllocatorDefault, _pixelBufferPool, &pixelBuffer);
  if (poolResult != kCVReturnSuccess || !pixelBuffer) {
    [_frameLock unlock];
    return;
  }

  CVPixelBufferLockBaseAddress(pixelBuffer, 0);
  void *destination = CVPixelBufferGetBaseAddress(pixelBuffer);
  const size_t destinationStride = CVPixelBufferGetBytesPerRow(pixelBuffer);

  vImage_Buffer sourceBuffer = {
      (void *)pixels,
      (vImagePixelCount)height,
      (vImagePixelCount)width,
      (size_t)linesize,
  };
  vImage_Buffer destinationBuffer = {
      destination,
      (vImagePixelCount)height,
      (vImagePixelCount)width,
      destinationStride,
  };

  uint8_t permuteMap[4];
  FillPermuteMap(pixelFormat, permuteMap);
  vImage_Error imageError = vImagePermuteChannels_ARGB8888(
      &sourceBuffer, &destinationBuffer, permuteMap, kvImageNoFlags);

  if (imageError == kvImageNoError && pixelFormat &&
      (strcmp(pixelFormat, "rgb0") == 0 ||
       strcmp(pixelFormat, "bgr0") == 0)) {
    uint8_t *row = (uint8_t *)destination;
    for (int y = 0; y < height; ++y) {
      for (int x = 0; x < width; ++x) {
        row[x * 4 + 3] = 0xFF;
      }
      row += destinationStride;
    }
  }

  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

  if (imageError != kvImageNoError) {
    CVPixelBufferRelease(pixelBuffer);
    [_frameLock unlock];
    return;
  }

  if (!_formatDescription) {
    OSStatus formatStatus = CMVideoFormatDescriptionCreateForImageBuffer(
        kCFAllocatorDefault, pixelBuffer, &_formatDescription);
    if (formatStatus != noErr || !_formatDescription) {
      CVPixelBufferRelease(pixelBuffer);
      [_frameLock unlock];
      return;
    }
  }

  CMSampleTimingInfo timing = {
      .duration = kCMTimeInvalid,
      .presentationTimeStamp = kCMTimeInvalid,
      .decodeTimeStamp = kCMTimeInvalid,
  };
  CMSampleBufferRef sampleBuffer = NULL;
  OSStatus sampleStatus = CMSampleBufferCreateReadyWithImageBuffer(
      kCFAllocatorDefault,
      pixelBuffer,
      _formatDescription,
      &timing,
      &sampleBuffer);
  CVPixelBufferRelease(pixelBuffer);

  if (sampleStatus != noErr || !sampleBuffer) {
    [_frameLock unlock];
    return;
  }

  CFArrayRef attachments =
      CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
  if (attachments && CFArrayGetCount(attachments) > 0) {
    CFMutableDictionaryRef attachment =
        (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionarySetValue(attachment,
                         kCMSampleAttachmentKey_DisplayImmediately,
                         kCFBooleanTrue);
  }

  // Keep only the latest decoded frame if the main thread is behind. This
  // prevents an unbounded dispatch queue and avoids introducing playback lag.
  if (_pendingSampleBuffer) {
    CFRelease(_pendingSampleBuffer);
  }
  _pendingSampleBuffer = sampleBuffer;

  BOOL shouldScheduleDisplay = !_displayDispatchPending;
  if (shouldScheduleDisplay) {
    _displayDispatchPending = YES;
  }
  [_frameLock unlock];

  if (shouldScheduleDisplay) {
    __weak RCTFFplayView *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf displayPendingFrame];
    });
  }
}

- (void)displayPendingFrame {
  CMSampleBufferRef sampleBuffer = NULL;

  [_frameLock lock];
  if (_pendingSampleBuffer) {
    sampleBuffer = _pendingSampleBuffer;
    _pendingSampleBuffer = NULL;
  }
  BOOL acceptFrames = _acceptFrames;
  [_frameLock unlock];

  if (sampleBuffer) {
    if (acceptFrames) {
      if (_displayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
        [_displayLayer flush];
      }
      [_displayLayer enqueueSampleBuffer:sampleBuffer];
    }
    CFRelease(sampleBuffer);
  }

  [_frameLock lock];
  BOOL hasAnotherFrame = _acceptFrames && _pendingSampleBuffer != NULL;
  if (!hasAnotherFrame) {
    _displayDispatchPending = NO;
  }
  [_frameLock unlock];

  if (hasAnotherFrame) {
    __weak RCTFFplayView *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf displayPendingFrame];
    });
  }
}

@end
