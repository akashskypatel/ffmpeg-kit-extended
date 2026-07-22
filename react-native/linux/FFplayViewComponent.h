#pragma once

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

#include "ReactSkia/components/RSkComponent.h"

namespace facebook::react {

class FFplayViewComponent final : public RSkComponent {
 public:
  explicit FFplayViewComponent(const ShadowView &shadowView);
  ~FFplayViewComponent() override;

  RnsShell::LayerInvalidateMask updateComponentProps(
      Props::Shared newViewProps,
      bool forceUpdate) override;

 protected:
  void OnPaint(SkCanvas *canvas) override;

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
                      const char *pixelFormat);

  void ActivateFrameOutput();
  void DeactivateFrameOutput();
  void QueueFrame(const std::uint8_t *data,
                  int width,
                  int height,
                  int linesize,
                  const char *pixelFormat);
  void DrainPendingFrame();

  static RegisterFrameCallback ResolveRegisterCallback();
  static UnregisterFrameCallback ResolveUnregisterCallback();

  std::mutex frameMutex_;
  std::atomic_bool acceptFrames_{false};
  bool dispatchPending_{false};

  std::vector<std::uint8_t> pendingFrame_;
  std::string pendingPixelFormat_;
  int pendingWidth_{0};
  int pendingHeight_{0};
  int pendingLinesize_{0};

  std::vector<std::uint8_t> currentFrame_;
  std::string currentPixelFormat_;
  int currentWidth_{0};
  int currentHeight_{0};
  int currentLinesize_{0};
};

} // namespace facebook::react
