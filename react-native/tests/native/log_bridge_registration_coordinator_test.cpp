#include "../../cpp/LogBridgeRegistrationCoordinator.h"

#include <atomic>
#include <cassert>
#include <stdexcept>
#include <thread>
#include <utility>
#include <vector>

namespace {

class FakeNativeRegistration final {
 public:
  void install(void *owner) {
    operations.push_back(owner);
    if (failInstall) throw std::runtime_error("install failed");
    nativeOwner = owner;
  }

  void disable() {
    operations.push_back(nullptr);
    if (failDisable) throw std::runtime_error("disable failed");
    nativeOwner = nullptr;
  }

  bool failInstall = false;
  bool failDisable = false;
  void *nativeOwner = nullptr;
  std::vector<void *> operations;
};

void install(ffmpegkit::bridge::LogBridgeRegistrationCoordinator &coordinator,
             FakeNativeRegistration &native,
             void *owner) {
  coordinator.install(owner, [&] { native.install(owner); });
}

bool uninstall(ffmpegkit::bridge::LogBridgeRegistrationCoordinator &coordinator,
               FakeNativeRegistration &native,
               void *owner) {
  return coordinator.uninstallIfOwned(owner, [&] { native.disable(); });
}

void testOwnershipTransitions() {
  ffmpegkit::bridge::LogBridgeRegistrationCoordinator coordinator;
  FakeNativeRegistration native;
  int ownerA = 0;
  int ownerB = 0;

  install(coordinator, native, &ownerA);
  assert(coordinator.isOwner(&ownerA));
  assert(native.nativeOwner == &ownerA);

  assert(uninstall(coordinator, native, &ownerA));
  install(coordinator, native, &ownerB);
  assert(!uninstall(coordinator, native, &ownerA));
  assert(coordinator.isOwner(&ownerB));
  assert(native.nativeOwner == &ownerB);

  assert(uninstall(coordinator, native, &ownerB));
  assert(!coordinator.isOwner(&ownerA));
  assert(native.nativeOwner == nullptr);
  assert(!uninstall(coordinator, native, &ownerA));
  assert(native.operations.size() == 4);
}

void testFailuresPreserveOwnership() {
  ffmpegkit::bridge::LogBridgeRegistrationCoordinator coordinator;
  FakeNativeRegistration native;
  int ownerA = 0;
  int ownerB = 0;

  install(coordinator, native, &ownerA);

  native.failInstall = true;
  try {
    install(coordinator, native, &ownerB);
    assert(false);
  } catch (const std::runtime_error &) {
  }
  native.failInstall = false;
  assert(coordinator.isOwner(&ownerA));
  assert(native.nativeOwner == &ownerA);

  native.failDisable = true;
  try {
    (void)uninstall(coordinator, native, &ownerA);
    assert(false);
  } catch (const std::runtime_error &) {
  }
  native.failDisable = false;
  assert(coordinator.isOwner(&ownerA));
  assert(native.nativeOwner == &ownerA);
  assert(uninstall(coordinator, native, &ownerA));
  assert(native.nativeOwner == nullptr);
}

void testConcurrentReplacementAndStaleTeardown() {
  ffmpegkit::bridge::LogBridgeRegistrationCoordinator coordinator;
  FakeNativeRegistration native;
  int ownerA = 0;
  int ownerB = 0;
  install(coordinator, native, &ownerA);

  std::atomic<int> ready = 0;
  std::atomic<bool> go = false;
  auto awaitStart = [&] {
    ready.fetch_add(1, std::memory_order_release);
    while (ready.load(std::memory_order_acquire) != 2) std::this_thread::yield();
    while (!go.load(std::memory_order_acquire)) std::this_thread::yield();
  };

  std::thread staleTeardown([&] {
    awaitStart();
    (void)uninstall(coordinator, native, &ownerA);
  });
  std::thread replacement([&] {
    awaitStart();
    install(coordinator, native, &ownerB);
  });
  while (ready.load(std::memory_order_acquire) != 2) std::this_thread::yield();
  go.store(true, std::memory_order_release);
  staleTeardown.join();
  replacement.join();

  assert(coordinator.isOwner(&ownerB));
  assert(native.nativeOwner == &ownerB);
  assert(uninstall(coordinator, native, &ownerB));
}

} // namespace

int main() {
  testOwnershipTransitions();
  testFailuresPreserveOwnership();
  testConcurrentReplacementAndStaleTeardown();
  return 0;
}
