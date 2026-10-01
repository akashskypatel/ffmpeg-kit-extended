#include "../../native/registered_texture_lifetime.h"

#include <cassert>
#include <cstdint>
#include <functional>
#include <memory>
#include <utility>

namespace {

struct TextureStateProbe {
  explicit TextureStateProbe(int64_t id, int* destruction_count)
      : texture_id(id), destruction_count(destruction_count) {}

  ~TextureStateProbe() {
    ++*destruction_count;
  }

  int64_t texture_id;
  int* destruction_count;
};

class ControllableTextureRegistrar {
 public:
  void UnregisterTexture(int64_t id, std::function<void()> callback) {
    unregister_id = id;
    completion = std::move(callback);
  }

  void CompleteUnregister() {
    auto callback = std::move(completion);
    if (callback) callback();
  }

  int64_t unregister_id = -1;
  std::function<void()> completion;
};

void AssertDeferredRetirement() {
  ControllableTextureRegistrar registrar;
  int destroyed = 0;
  auto state = std::make_unique<TextureStateProbe>(17, &destroyed);
  auto* state_pointer = state.get();

  ffmpeg_kit_extended_flutter::RetireRegisteredTexture(&registrar,
                                                       std::move(state));

  assert(registrar.unregister_id == 17);
  assert(registrar.completion);
  assert(destroyed == 0);
  assert(state_pointer != nullptr);

  registrar.CompleteUnregister();
  assert(destroyed == 1);
  assert(!registrar.completion);
}

void AssertImmediateRetirement() {
  struct ImmediateRegistrar {
    void UnregisterTexture(int64_t id, std::function<void()> callback) {
      unregister_id = id;
      callback();
    }

    int64_t unregister_id = -1;
  } registrar;

  int destroyed = 0;
  ffmpeg_kit_extended_flutter::RetireRegisteredTexture(
      &registrar, std::make_unique<TextureStateProbe>(23, &destroyed));

  assert(registrar.unregister_id == 23);
  assert(destroyed == 1);
}

void AssertIndependentOverlappingRetirements() {
  ControllableTextureRegistrar registrar;
  int first_destroyed = 0;
  int second_destroyed = 0;

  ffmpeg_kit_extended_flutter::RetireRegisteredTexture(
      &registrar, std::make_unique<TextureStateProbe>(31, &first_destroyed));
  auto first_completion = std::move(registrar.completion);
  ffmpeg_kit_extended_flutter::RetireRegisteredTexture(
      &registrar, std::make_unique<TextureStateProbe>(32, &second_destroyed));

  registrar.CompleteUnregister();
  assert(first_destroyed == 0);
  assert(second_destroyed == 1);

  first_completion();
  assert(first_destroyed == 1);
}

void AssertUnregisteredStateIsReleasedWithoutCallback() {
  int destroyed = 0;
  auto state = std::make_unique<TextureStateProbe>(-1, &destroyed);

  ffmpeg_kit_extended_flutter::RetireRegisteredTexture(
      static_cast<ControllableTextureRegistrar*>(nullptr), std::move(state));

  assert(destroyed == 1);
}

}  // namespace

int main() {
  AssertDeferredRetirement();
  AssertImmediateRetirement();
  AssertIndependentOverlappingRetirements();
  AssertUnregisteredStateIsReleasedWithoutCallback();
  return 0;
}
