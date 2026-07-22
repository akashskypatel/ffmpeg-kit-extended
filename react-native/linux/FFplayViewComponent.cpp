#include "third_party/ffmpeg-kit-extended/linux/FFplayViewComponent.h"

#include <cstddef>
#include <dlfcn.h>
#include <memory>

#include "include/core/SkImage.h"
#include "include/core/SkImageInfo.h"
#include "include/core/SkPixmap.h"
#include "include/core/SkSamplingOptions.h"
#include "rns_shell/platform/linux/TaskLoop.h"

namespace facebook::react {
namespace {

std::mutex g_registrationMutex;
FFplayViewComponent *g_activeView = nullptr;
void *g_ffmpegKitHandle = nullptr;

void *LoadFFmpegKit() {
  if (g_ffmpegKitHandle) {
    return g_ffmpegKitHandle;
  }

  const char *libraries[] = {
      "libffmpegkit.so",
      "libffmpegkit.so.0",
      "libffmpegkit.so.1",
      nullptr,
  };

  for (const char **library = libraries; *library; ++library) {
    g_ffmpegKitHandle = dlopen(*library, RTLD_NOW | RTLD_LOCAL);
    if (g_ffmpegKitHandle) {
      break;
    }
  }

  return g_ffmpegKitHandle;
}

void ConvertToRGBA(const std::uint8_t *source,
                   int width,
                   int height,
                   int sourceStride,
                   const std::string &pixelFormat,
                   std::vector<std::uint8_t> &destination) {
  const auto destinationStride = static_cast<std::size_t>(width) * 4;
  destination.resize(destinationStride * static_cast<std::size_t>(height));

  const bool rgb = pixelFormat == "rgb0" || pixelFormat == "rgba";
  const bool bgr = pixelFormat == "bgr0" || pixelFormat == "bgra";
  const bool argb = pixelFormat == "argb";
  const bool abgr = pixelFormat == "abgr";
  const bool unusedAlpha = pixelFormat == "rgb0" || pixelFormat == "bgr0";

  for (int y = 0; y < height; ++y) {
    const auto *src = source +
        static_cast<std::ptrdiff_t>(y) * static_cast<std::ptrdiff_t>(sourceStride);
    auto *dst = destination.data() +
        static_cast<std::ptrdiff_t>(y) * static_cast<std::ptrdiff_t>(destinationStride);

    for (int x = 0; x < width; ++x) {
      const auto *pixel = src + x * 4;
      auto *out = dst + x * 4;

      if (rgb) {
        out[0] = pixel[0];
        out[1] = pixel[1];
        out[2] = pixel[2];
        out[3] = unusedAlpha ? 0xff : pixel[3];
      } else if (bgr) {
        out[0] = pixel[2];
        out[1] = pixel[1];
        out[2] = pixel[0];
        out[3] = unusedAlpha ? 0xff : pixel[3];
      } else if (argb) {
        out[0] = pixel[1];
        out[1] = pixel[2];
        out[2] = pixel[3];
        out[3] = pixel[0];
      } else if (abgr) {
        out[0] = pixel[3];
        out[1] = pixel[2];
        out[2] = pixel[1];
        out[3] = pixel[0];
      } else {
        out[0] = pixel[0];
        out[1] = pixel[1];
        out[2] = pixel[2];
        out[3] = pixel[3];
      }
    }
  }
}

} // namespace

const char FFplayViewComponentName[] = "FFplayView";

FFplayViewComponent::FFplayViewComponent(const ShadowView &shadowView)
    : RSkComponent(shadowView) {
  ActivateFrameOutput();
}

FFplayViewComponent::~FFplayViewComponent() {
  DeactivateFrameOutput();

  std::lock_guard<std::mutex> lock(frameMutex_);
  pendingFrame_.clear();
  currentFrame_.clear();
  dispatchPending_ = false;
}

RnsShell::LayerInvalidateMask FFplayViewComponent::updateComponentProps(
    Props::Shared /*newViewProps*/,
    bool /*forceUpdate*/) {
  return RnsShell::LayerInvalidateAll;
}

void FFplayViewComponent::OnPaint(SkCanvas *canvas) {
  if (!canvas) {
    return;
  }

  canvas->clear(SK_ColorBLACK);

  std::vector<std::uint8_t> frame;
  std::string pixelFormat;
  int width = 0;
  int height = 0;
  int linesize = 0;

  {
    std::lock_guard<std::mutex> lock(frameMutex_);
    if (currentFrame_.empty()) {
      return;
    }

    frame = currentFrame_;
    pixelFormat = currentPixelFormat_;
    width = currentWidth_;
    height = currentHeight_;
    linesize = currentLinesize_;
  }

  if (width <= 0 || height <= 0 || linesize < width * 4) {
    return;
  }

  std::vector<std::uint8_t> rgba;
  ConvertToRGBA(
      frame.data(), width, height, linesize, pixelFormat, rgba);

  const auto imageInfo = SkImageInfo::Make(
      width,
      height,
      kRGBA_8888_SkColorType,
      kUnpremul_SkAlphaType);
  const SkPixmap pixmap(
      imageInfo,
      rgba.data(),
      static_cast<std::size_t>(width) * 4);
  auto image = SkImage::MakeRasterCopy(pixmap);
  if (!image) {
    return;
  }

  SkRect bounds;
  if (!canvas->getLocalClipBounds(&bounds) || bounds.isEmpty()) {
    return;
  }

  const float sourceAspect =
      static_cast<float>(width) / static_cast<float>(height);
  const float targetAspect = bounds.width() / bounds.height();

  SkRect destination = bounds;
  if (targetAspect > sourceAspect) {
    const float displayWidth = bounds.height() * sourceAspect;
    const float left = bounds.left() + (bounds.width() - displayWidth) * 0.5f;
    destination = SkRect::MakeXYWH(
        left, bounds.top(), displayWidth, bounds.height());
  } else {
    const float displayHeight = bounds.width() / sourceAspect;
    const float top = bounds.top() + (bounds.height() - displayHeight) * 0.5f;
    destination = SkRect::MakeXYWH(
        bounds.left(), top, bounds.width(), displayHeight);
  }

  canvas->drawImageRect(
      image,
      destination,
      SkSamplingOptions(SkFilterMode::kLinear),
      nullptr);
}

void FFplayViewComponent::ActivateFrameOutput() {
  auto registerCallback = ResolveRegisterCallback();
  if (!registerCallback) {
    return;
  }

  std::lock_guard<std::mutex> registrationLock(g_registrationMutex);
  if (g_activeView == this && acceptFrames_.load(std::memory_order_acquire)) {
    return;
  }

  if (g_activeView) {
    g_activeView->acceptFrames_.store(false, std::memory_order_release);
    if (auto unregisterCallback = ResolveUnregisterCallback()) {
      unregisterCallback();
    }
  }

  g_activeView = this;
  acceptFrames_.store(true, std::memory_order_release);
  registerCallback(&FFplayViewComponent::OnFrame, this);
}

void FFplayViewComponent::DeactivateFrameOutput() {
  acceptFrames_.store(false, std::memory_order_release);

  std::lock_guard<std::mutex> registrationLock(g_registrationMutex);
  if (g_activeView != this) {
    return;
  }

  if (auto unregisterCallback = ResolveUnregisterCallback()) {
    unregisterCallback();
  }
  g_activeView = nullptr;
}

void FFplayViewComponent::OnFrame(void *userdata,
                                  const std::uint8_t *data,
                                  int width,
                                  int height,
                                  int linesize,
                                  const char *pixelFormat) {
  auto *view = static_cast<FFplayViewComponent *>(userdata);
  if (!view || !view->acceptFrames_.load(std::memory_order_acquire)) {
    return;
  }

  view->QueueFrame(data, width, height, linesize, pixelFormat);
}

void FFplayViewComponent::QueueFrame(const std::uint8_t *data,
                                     int width,
                                     int height,
                                     int linesize,
                                     const char *pixelFormat) {
  if (!data || width <= 0 || height <= 0 || linesize < width * 4 ||
      !acceptFrames_.load(std::memory_order_acquire)) {
    return;
  }

  bool shouldDispatch = false;
  {
    std::lock_guard<std::mutex> lock(frameMutex_);
    if (!acceptFrames_.load(std::memory_order_acquire)) {
      return;
    }

    const auto byteCount = static_cast<std::size_t>(linesize) *
        static_cast<std::size_t>(height);
    pendingFrame_.assign(data, data + byteCount);
    pendingPixelFormat_ = pixelFormat ? pixelFormat : "";
    pendingWidth_ = width;
    pendingHeight_ = height;
    pendingLinesize_ = linesize;

    if (!dispatchPending_) {
      dispatchPending_ = true;
      shouldDispatch = true;
    }
  }

  if (!shouldDispatch) {
    return;
  }

  auto weakSelf = weak_from_this();
  RnsShell::TaskLoop::main().dispatch([weakSelf]() {
    auto component = weakSelf.lock();
    if (!component) {
      return;
    }

    auto self = std::static_pointer_cast<FFplayViewComponent>(component);
    self->DrainPendingFrame();
  });
}

void FFplayViewComponent::DrainPendingFrame() {
  {
    std::lock_guard<std::mutex> lock(frameMutex_);
    dispatchPending_ = false;

    if (!acceptFrames_.load(std::memory_order_acquire) || pendingFrame_.empty()) {
      pendingFrame_.clear();
      return;
    }

    currentFrame_.swap(pendingFrame_);
    currentPixelFormat_.swap(pendingPixelFormat_);
    currentWidth_ = pendingWidth_;
    currentHeight_ = pendingHeight_;
    currentLinesize_ = pendingLinesize_;
  }

  drawAndSubmit(RnsShell::LayerInvalidateAll);
}

FFplayViewComponent::RegisterFrameCallback
FFplayViewComponent::ResolveRegisterCallback() {
  auto callback = reinterpret_cast<RegisterFrameCallback>(
      dlsym(RTLD_DEFAULT, "ffplay_kit_register_frame_callback"));
  if (callback) {
    return callback;
  }

  auto handle = LoadFFmpegKit();
  return handle
      ? reinterpret_cast<RegisterFrameCallback>(
            dlsym(handle, "ffplay_kit_register_frame_callback"))
      : nullptr;
}

FFplayViewComponent::UnregisterFrameCallback
FFplayViewComponent::ResolveUnregisterCallback() {
  auto callback = reinterpret_cast<UnregisterFrameCallback>(
      dlsym(RTLD_DEFAULT, "ffplay_kit_unregister_frame_callback"));
  if (callback) {
    return callback;
  }

  auto handle = LoadFFmpegKit();
  return handle
      ? reinterpret_cast<UnregisterFrameCallback>(
            dlsym(handle, "ffplay_kit_unregister_frame_callback"))
      : nullptr;
}

} // namespace facebook::react
