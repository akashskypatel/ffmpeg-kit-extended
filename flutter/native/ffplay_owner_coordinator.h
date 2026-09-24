#ifndef FFMPEG_KIT_EXTENDED_FLUTTER_FFPLAY_OWNER_COORDINATOR_H_
#define FFMPEG_KIT_EXTENDED_FLUTTER_FFPLAY_OWNER_COORDINATOR_H_

#include <mutex>
#include <type_traits>
#include <utility>

namespace ffmpeg_kit_extended_flutter {

// Coordinates one process-global FFplay callback target. The native install
// and unregister operations run while the coordinator is locked, so a stale
// wrapper instance cannot unregister a newer successful owner.
template <typename Owner>
class FfplayOwnerCoordinator {
 public:
  FfplayOwnerCoordinator() = default;

  FfplayOwnerCoordinator(const FfplayOwnerCoordinator&) = delete;
  FfplayOwnerCoordinator& operator=(const FfplayOwnerCoordinator&) = delete;

  template <typename Install>
  bool install(Owner* owner, Install&& native_install) {
    if (!owner) return false;
    std::lock_guard<std::mutex> lock(mutex_);
    using Result = std::invoke_result_t<Install>;
    if constexpr (std::is_same_v<Result, bool>) {
      if (!std::forward<Install>(native_install)()) return false;
    } else {
      std::forward<Install>(native_install)();
    }
    owner_ = owner;
    return true;
  }

  template <typename Uninstall>
  bool uninstallIfOwned(Owner* owner, Uninstall&& native_uninstall) {
    if (!owner) return false;
    std::lock_guard<std::mutex> lock(mutex_);
    if (owner_ != owner) return false;
    std::forward<Uninstall>(native_uninstall)();
    owner_ = nullptr;
    return true;
  }

  bool isOwner(const Owner* owner) const {
    std::lock_guard<std::mutex> lock(mutex_);
    return owner_ == owner;
  }

 private:
  mutable std::mutex mutex_;
  Owner* owner_ = nullptr;
};

}  // namespace ffmpeg_kit_extended_flutter

#endif  // FFMPEG_KIT_EXTENDED_FLUTTER_FFPLAY_OWNER_COORDINATOR_H_
