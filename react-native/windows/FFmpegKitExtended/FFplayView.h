#pragma once

#include "pch.h"

#ifdef RNW_NEW_ARCH
#include "codegen/react/components/FFmpegKitExtendedSpec/FFplayView.g.h"
#endif

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

namespace winrt::FFmpegKitExtended {

void RegisterFFplayViewNativeComponent(
    winrt::Microsoft::ReactNative::IReactPackageBuilder const &packageBuilder) noexcept;

#ifdef RNW_NEW_ARCH
struct FFplayViewComponentView
    : winrt::implements<FFplayViewComponentView, winrt::IInspectable>,
      FFmpegKitExtendedCodegen::BaseFFplayView<FFplayViewComponentView> {
  winrt::Microsoft::UI::Composition::Visual CreateVisual(
      winrt::Microsoft::ReactNative::ComponentView const &view) noexcept override;
  void Initialize(
      winrt::Microsoft::ReactNative::ComponentView const &view) noexcept override;

  ~FFplayViewComponentView();

 private:
  using FrameCallback = void (*)(void *userdata,
                                 const std::uint8_t *data,
                                 int width,
                                 int height,
                                 int linesize,
                                 const char *pixelFormat);
  using RegisterFrameCallback = void (*)(FrameCallback callback, void *userdata);
  using UnregisterFrameCallback = void (*)();

  static void OnFrame(void *userdata,
                      const std::uint8_t *data,
                      int width,
                      int height,
                      int linesize,
                      const char *pixelFormat) noexcept;

  void QueueFrame(const std::uint8_t *data,
                  int width,
                  int height,
                  int linesize,
                  const char *pixelFormat) noexcept;
  void DrainPendingFrame() noexcept;
  void RenderFrame(const std::uint8_t *data,
                   int width,
                   int height,
                   int linesize,
                   const char *pixelFormat) noexcept;
  bool EnsureDrawingSurface(int width, int height) noexcept;
  static HMODULE LoadFFmpegKitModule() noexcept;
  static RegisterFrameCallback ResolveRegisterCallback() noexcept;
  static UnregisterFrameCallback ResolveUnregisterCallback() noexcept;

  std::mutex m_frameMutex;
  std::atomic_bool m_acceptFrames{false};
  bool m_frameDispatchPending{false};
  std::vector<std::uint8_t> m_pendingFrame;
  std::string m_pendingPixelFormat;
  int m_pendingWidth{0};
  int m_pendingHeight{0};
  int m_pendingLinesize{0};
  winrt::Microsoft::UI::Dispatching::DispatcherQueue m_dispatcherQueue{nullptr};
  winrt::Microsoft::UI::Composition::SpriteVisual m_visual{nullptr};
  winrt::Microsoft::ReactNative::Composition::Experimental::IDrawingSurfaceBrush
      m_drawingSurfaceBrush{nullptr};
  int m_surfaceWidth{0};
  int m_surfaceHeight{0};
};
#endif

} // namespace winrt::FFmpegKitExtended
