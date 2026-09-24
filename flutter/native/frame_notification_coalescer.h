#ifndef FFMPEG_KIT_EXTENDED_FLUTTER_FRAME_NOTIFICATION_COALESCER_H_
#define FFMPEG_KIT_EXTENDED_FLUTTER_FRAME_NOTIFICATION_COALESCER_H_

namespace ffmpeg_kit_extended_flutter {

// The owner of this value must serialize calls with its frame state mutex.
// Keeping the pending bit separate from frame pixels lets a slow main loop
// coalesce notifications without dropping the latest frame.
class FrameNotificationCoalescer final {
 public:
  bool request() noexcept {
    if (frame_mark_pending_) return false;
    frame_mark_pending_ = true;
    return true;
  }

  void consume() noexcept { frame_mark_pending_ = false; }

  bool isPending() const noexcept { return frame_mark_pending_; }

 private:
  bool frame_mark_pending_ = false;
};

}  // namespace ffmpeg_kit_extended_flutter

#endif  // FFMPEG_KIT_EXTENDED_FLUTTER_FRAME_NOTIFICATION_COALESCER_H_
