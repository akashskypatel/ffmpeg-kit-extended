#include "pch.h"
#include "FFplayView.h"

#include <AutoDraw.h>
#include <d2d1_1.h>
#include <dxgi1_2.h>

#include <algorithm>
#include <cstring>

namespace winrt::FFmpegKitExtended {

using namespace winrt::Microsoft::ReactNative;
using namespace winrt::Microsoft::ReactNative::Composition::Experimental;
using namespace winrt::Microsoft::UI::Composition;
using namespace winrt::Windows::Graphics::DirectX;

#ifdef RNW_NEW_ARCH
namespace {

std::mutex g_registrationMutex;
FFplayViewComponentView *g_activeView = nullptr;

void DebugMessage(const char *message) noexcept {
  OutputDebugStringA(message);
  OutputDebugStringA("\n");
}

void ConvertToBGRA(const std::uint8_t *source,
                   int width,
                   int height,
                   int sourceStride,
                   const char *pixelFormat,
                   std::vector<std::uint8_t> &destination) {
  const int destinationStride = width * 4;
  destination.resize(static_cast<std::size_t>(destinationStride) *
                     static_cast<std::size_t>(height));

  const bool rgb = pixelFormat &&
                   (std::strcmp(pixelFormat, "rgb0") == 0 ||
                    std::strcmp(pixelFormat, "rgba") == 0);
  const bool bgr = pixelFormat &&
                   (std::strcmp(pixelFormat, "bgr0") == 0 ||
                    std::strcmp(pixelFormat, "bgra") == 0);
  const bool argb = pixelFormat && std::strcmp(pixelFormat, "argb") == 0;
  const bool abgr = pixelFormat && std::strcmp(pixelFormat, "abgr") == 0;
  const bool unusedAlpha = pixelFormat &&
                           (std::strcmp(pixelFormat, "rgb0") == 0 ||
                            std::strcmp(pixelFormat, "bgr0") == 0);

  for (int y = 0; y < height; ++y) {
    const auto *src = source + static_cast<std::ptrdiff_t>(y) * sourceStride;
    auto *dst = destination.data() +
                static_cast<std::ptrdiff_t>(y) * destinationStride;

    for (int x = 0; x < width; ++x) {
      const auto *pixel = src + x * 4;
      auto *out = dst + x * 4;

      if (rgb) {
        out[0] = pixel[2];
        out[1] = pixel[1];
        out[2] = pixel[0];
        out[3] = unusedAlpha ? 0xff : pixel[3];
      } else if (bgr) {
        out[0] = pixel[0];
        out[1] = pixel[1];
        out[2] = pixel[2];
        out[3] = unusedAlpha ? 0xff : pixel[3];
      } else if (argb) {
        out[0] = pixel[3];
        out[1] = pixel[2];
        out[2] = pixel[1];
        out[3] = pixel[0];
      } else if (abgr) {
        out[0] = pixel[1];
        out[1] = pixel[2];
        out[2] = pixel[3];
        out[3] = pixel[0];
      } else {
        // Desktop FFplay currently emits four-byte packed frames. Preserve an
        // unknown four-byte layout instead of dropping playback completely.
        out[0] = pixel[0];
        out[1] = pixel[1];
        out[2] = pixel[2];
        out[3] = pixel[3];
      }
    }
  }
}

} // namespace
#endif

void RegisterFFplayViewNativeComponent(
    IReactPackageBuilder const &packageBuilder) noexcept {
#ifdef RNW_NEW_ARCH
  FFmpegKitExtendedCodegen::RegisterFFplayViewNativeComponent<FFplayViewComponentView>(
      packageBuilder,
      [](winrt::Microsoft::ReactNative::Composition::IReactCompositionViewComponentBuilder const &) {});
#else
  UNREFERENCED_PARAMETER(packageBuilder);
#endif
}

#ifdef RNW_NEW_ARCH
Visual FFplayViewComponentView::CreateVisual(
    ComponentView const &view) noexcept {
  auto compositionView =
      view.as<winrt::Microsoft::ReactNative::Composition::ViewComponentView>();
  m_visual = compositionView.Compositor().CreateSpriteVisual();
  return m_visual;
}

void FFplayViewComponentView::Initialize(
    ComponentView const & /*view*/) noexcept {
  m_dispatcherQueue =
      winrt::Microsoft::UI::Dispatching::DispatcherQueue::GetForCurrentThread();

  auto registerCallback = ResolveRegisterCallback();
  if (!registerCallback) {
    DebugMessage(
        "FFmpegKitExtended: ffplay_kit_register_frame_callback was not found.");
    return;
  }

  std::lock_guard<std::mutex> registrationLock(g_registrationMutex);
  if (g_activeView == this &&
      m_acceptFrames.load(std::memory_order_acquire)) {
    return;
  }

  if (g_activeView) {
    g_activeView->m_acceptFrames.store(false, std::memory_order_release);
    if (auto unregisterCallback = ResolveUnregisterCallback()) {
      unregisterCallback();
    }
  }

  g_activeView = this;
  m_acceptFrames.store(true, std::memory_order_release);
  registerCallback(&FFplayViewComponentView::OnFrame, this);
}

FFplayViewComponentView::~FFplayViewComponentView() {
  m_acceptFrames.store(false, std::memory_order_release);

  {
    std::lock_guard<std::mutex> registrationLock(g_registrationMutex);
    if (g_activeView == this) {
      if (auto unregisterCallback = ResolveUnregisterCallback()) {
        unregisterCallback();
      }
      g_activeView = nullptr;
    }
  }

  // The FFmpegKit callback unregister path drains the global callback before
  // returning. Taking the frame lock afterwards also waits for a frame already
  // being copied/drawn by this component.
  std::lock_guard<std::mutex> frameLock(m_frameMutex);
  m_pendingFrame.clear();
  m_frameDispatchPending = false;
}

void FFplayViewComponentView::OnFrame(void *userdata,
                                      const std::uint8_t *data,
                                      int width,
                                      int height,
                                      int linesize,
                                      const char *pixelFormat) noexcept {
  auto *view = static_cast<FFplayViewComponentView *>(userdata);
  if (!view || !view->m_acceptFrames.load(std::memory_order_acquire)) {
    return;
  }

  view->QueueFrame(data, width, height, linesize, pixelFormat);
}

void FFplayViewComponentView::QueueFrame(const std::uint8_t *data,
                                         int width,
                                         int height,
                                         int linesize,
                                         const char *pixelFormat) noexcept {
  if (!data || width <= 0 || height <= 0 || linesize < width * 4 ||
      !m_acceptFrames.load(std::memory_order_acquire) || !m_dispatcherQueue) {
    return;
  }

  bool enqueue = false;
  {
    std::lock_guard<std::mutex> frameLock(m_frameMutex);
    if (!m_acceptFrames.load(std::memory_order_acquire)) {
      return;
    }

    const auto byteCount = static_cast<std::size_t>(linesize) *
                           static_cast<std::size_t>(height);
    m_pendingFrame.assign(data, data + byteCount);
    m_pendingWidth = width;
    m_pendingHeight = height;
    m_pendingLinesize = linesize;
    m_pendingPixelFormat = pixelFormat ? pixelFormat : "";

    if (!m_frameDispatchPending) {
      m_frameDispatchPending = true;
      enqueue = true;
    }
  }

  if (!enqueue) {
    return;
  }

  auto weakThis = get_weak();
  if (!m_dispatcherQueue.TryEnqueue([weakThis]() noexcept {
        if (auto strongThis = weakThis.get()) {
          strongThis->DrainPendingFrame();
        }
      })) {
    std::lock_guard<std::mutex> frameLock(m_frameMutex);
    m_frameDispatchPending = false;
  }
}

void FFplayViewComponentView::DrainPendingFrame() noexcept {
  std::vector<std::uint8_t> frame;
  std::string pixelFormat;
  int width = 0;
  int height = 0;
  int linesize = 0;

  {
    std::lock_guard<std::mutex> frameLock(m_frameMutex);
    m_frameDispatchPending = false;
    if (!m_acceptFrames.load(std::memory_order_acquire) ||
        m_pendingFrame.empty()) {
      m_pendingFrame.clear();
      return;
    }

    frame.swap(m_pendingFrame);
    pixelFormat.swap(m_pendingPixelFormat);
    width = m_pendingWidth;
    height = m_pendingHeight;
    linesize = m_pendingLinesize;
  }

  RenderFrame(frame.data(), width, height, linesize, pixelFormat.c_str());
}

void FFplayViewComponentView::RenderFrame(const std::uint8_t *data,
                                          int width,
                                          int height,
                                          int linesize,
                                          const char *pixelFormat) noexcept {
  if (!data || width <= 0 || height <= 0 || linesize < width * 4 ||
      !m_acceptFrames.load(std::memory_order_acquire)) {
    return;
  }

  if (!m_acceptFrames.load(std::memory_order_acquire) ||
      !EnsureDrawingSurface(width, height)) {
    return;
  }

  try {
    std::vector<std::uint8_t> pixels;
    ConvertToBGRA(data, width, height, linesize, pixelFormat, pixels);

    POINT offset{};
    ::Microsoft::ReactNative::Composition::AutoDrawDrawingSurface autoDraw(
        m_drawingSurfaceBrush, 1.0f, &offset);
    auto *deviceContext = autoDraw.GetRenderTarget();
    if (!deviceContext) {
      return;
    }

    D2D1_BITMAP_PROPERTIES1 properties{};
    properties.pixelFormat.format = DXGI_FORMAT_B8G8R8A8_UNORM;
    properties.pixelFormat.alphaMode = D2D1_ALPHA_MODE_IGNORE;
    properties.bitmapOptions = D2D1_BITMAP_OPTIONS_NONE;
    properties.dpiX = 96.0f;
    properties.dpiY = 96.0f;

    winrt::com_ptr<ID2D1Bitmap1> bitmap;
    winrt::check_hresult(deviceContext->CreateBitmap(
        D2D1::SizeU(static_cast<UINT32>(width), static_cast<UINT32>(height)),
        pixels.data(),
        static_cast<UINT32>(width * 4),
        &properties,
        bitmap.put()));

    deviceContext->SetTransform(
        D2D1::Matrix3x2F::Translation(
            static_cast<float>(offset.x), static_cast<float>(offset.y)));
    deviceContext->Clear(D2D1::ColorF(D2D1::ColorF::Black, 0.0f));
    deviceContext->DrawBitmap(
        bitmap.get(),
        D2D1::RectF(0.0f,
                    0.0f,
                    static_cast<float>(width),
                    static_cast<float>(height)),
        1.0f,
        D2D1_INTERPOLATION_MODE_LINEAR);
  } catch (...) {
    // Rendering failure must never unwind through the FFplay presentation path.
    DebugMessage("FFmpegKitExtended: failed to render an FFplay frame.");
  }
}

bool FFplayViewComponentView::EnsureDrawingSurface(int width,
                                                   int height) noexcept {
  if (m_drawingSurfaceBrush && width == m_surfaceWidth &&
      height == m_surfaceHeight) {
    return true;
  }

  if (!m_visual) {
    return false;
  }

  try {
    auto context = MicrosoftCompositionContextHelper::CreateContext(
        m_visual.Compositor());
    m_drawingSurfaceBrush = context.CreateDrawingSurfaceBrush(
        {static_cast<float>(width), static_cast<float>(height)},
        DirectXPixelFormat::B8G8R8A8UIntNormalized,
        DirectXAlphaMode::Ignore);

    m_drawingSurfaceBrush.Stretch(
        winrt::Microsoft::ReactNative::Composition::Experimental::CompositionStretch::Uniform);
    m_visual.Brush(
        MicrosoftCompositionContextHelper::InnerBrush(m_drawingSurfaceBrush));

    m_surfaceWidth = width;
    m_surfaceHeight = height;
    return true;
  } catch (...) {
    m_drawingSurfaceBrush = nullptr;
    m_surfaceWidth = 0;
    m_surfaceHeight = 0;
    DebugMessage(
        "FFmpegKitExtended: failed to create the FFplay drawing surface.");
    return false;
  }
}

HMODULE FFplayViewComponentView::LoadFFmpegKitModule() noexcept {
  HMODULE module = GetModuleHandleA("libffmpegkit.dll");
  if (!module) {
    module = GetModuleHandleA("ffmpegkit.dll");
  }
  if (!module) {
    module = LoadLibraryA("libffmpegkit.dll");
  }
  if (!module) {
    module = LoadLibraryA("ffmpegkit.dll");
  }
  return module;
}

FFplayViewComponentView::RegisterFrameCallback
FFplayViewComponentView::ResolveRegisterCallback() noexcept {
  static RegisterFrameCallback callback = []() noexcept {
    auto module = LoadFFmpegKitModule();
    return module
               ? reinterpret_cast<RegisterFrameCallback>(GetProcAddress(
                     module, "ffplay_kit_register_frame_callback"))
               : nullptr;
  }();
  return callback;
}

FFplayViewComponentView::UnregisterFrameCallback
FFplayViewComponentView::ResolveUnregisterCallback() noexcept {
  static UnregisterFrameCallback callback = []() noexcept {
    auto module = LoadFFmpegKitModule();
    return module
               ? reinterpret_cast<UnregisterFrameCallback>(GetProcAddress(
                     module, "ffplay_kit_unregister_frame_callback"))
               : nullptr;
  }();
  return callback;
}

#endif // RNW_NEW_ARCH

} // namespace winrt::FFmpegKitExtended
