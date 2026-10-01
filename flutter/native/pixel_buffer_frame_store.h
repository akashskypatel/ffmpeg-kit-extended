#ifndef FFMPEG_KIT_EXTENDED_FLUTTER_PIXEL_BUFFER_FRAME_STORE_H_
#define FFMPEG_KIT_EXTENDED_FLUTTER_PIXEL_BUFFER_FRAME_STORE_H_

#include <cstddef>
#include <cstdint>
#include <utility>
#include <vector>

namespace ffmpeg_kit_extended_flutter {

// The Flutter pixel-buffer callback may retain the returned bytes until the
// texture is unregistered. Keep a dedicated render buffer separate from the
// producer double buffer so frame callbacks cannot overwrite bytes still owned
// by the render thread.
class PixelBufferFrameStore final {
 public:
  PixelBufferFrameStore() : render_buffer_{0, 0, 0, 255} {}

  void publish(const uint8_t* pixels, std::size_t byte_count, uint32_t width,
               uint32_t height) {
    producer_buffer_.assign(pixels, pixels + byte_count);
    width_ = width;
    height_ = height;
    std::swap(producer_buffer_, pending_buffer_);
    has_pending_frame_ = true;
  }

  bool copyForRender(const uint8_t** buffer, uint32_t* width,
                     uint32_t* height) {
    if (!buffer || !width || !height || destroyed_) return false;
    if (has_pending_frame_) {
      render_buffer_ = pending_buffer_;
      has_pending_frame_ = false;
    }
    *buffer = render_buffer_.data();
    *width = width_ > 0 ? width_ : 1;
    *height = height_ > 0 ? height_ : 1;
    return true;
  }

  void markDestroyed() noexcept {
    destroyed_ = true;
    has_pending_frame_ = false;
  }

  void resetForReuse() noexcept {
    destroyed_ = false;
    has_pending_frame_ = false;
  }

  void clearAfterUnregister() noexcept {
    producer_buffer_.clear();
    pending_buffer_.clear();
    render_buffer_.clear();
    has_pending_frame_ = false;
  }

  bool destroyed() const noexcept { return destroyed_; }
  bool hasPendingFrame() const noexcept { return has_pending_frame_; }
  std::size_t renderBufferSize() const noexcept { return render_buffer_.size(); }

 private:
  std::vector<uint8_t> producer_buffer_;
  std::vector<uint8_t> pending_buffer_;
  std::vector<uint8_t> render_buffer_;
  uint32_t width_ = 1;
  uint32_t height_ = 1;
  bool has_pending_frame_ = false;
  bool destroyed_ = false;
};

}  // namespace ffmpeg_kit_extended_flutter

#endif  // FFMPEG_KIT_EXTENDED_FLUTTER_PIXEL_BUFFER_FRAME_STORE_H_
