#pragma once

#include <mutex>
#include <utility>

namespace ffmpegkit::bridge {

/**
 * Serializes access to FFmpegKit's one process-global log callback pair.
 *
 * The callback user data remains owned by the module/state that installed it;
 * this coordinator only records which state may clear the global registration.
 * The latest successful install wins and stale teardown never restores an old
 * registration.
 */
class LogBridgeRegistrationCoordinator final {
 public:
  using Owner = void *;

  template <typename InstallFn>
  void install(Owner owner, InstallFn &&installFn) {
    std::lock_guard<std::mutex> lock(mutex_);
    std::forward<InstallFn>(installFn)();
    currentOwner_ = owner;
  }

  template <typename UninstallFn>
  bool uninstallIfOwned(Owner owner, UninstallFn &&uninstallFn) {
    std::lock_guard<std::mutex> lock(mutex_);
    if (currentOwner_ != owner) return false;

    std::forward<UninstallFn>(uninstallFn)();
    currentOwner_ = nullptr;
    return true;
  }

  bool isOwner(Owner owner) const {
    std::lock_guard<std::mutex> lock(mutex_);
    return currentOwner_ == owner;
  }

 private:
  mutable std::mutex mutex_;
  Owner currentOwner_ = nullptr;
};

} // namespace ffmpegkit::bridge
