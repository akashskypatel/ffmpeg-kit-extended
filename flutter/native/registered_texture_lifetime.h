#ifndef FFMPEG_KIT_EXTENDED_FLUTTER_REGISTERED_TEXTURE_LIFETIME_H_
#define FFMPEG_KIT_EXTENDED_FLUTTER_REGISTERED_TEXTURE_LIFETIME_H_

#include <cstdint>
#include <functional>
#include <memory>

namespace ffmpeg_kit_extended_flutter {

// Owns a registered texture until the embedder confirms that its callback
// userdata is no longer reachable. The registrar owns the completion callback;
// the callback owns this retirement record until the state is released.
template <typename State>
struct RetiringRegisteredTexture {
  explicit RetiringRegisteredTexture(std::unique_ptr<State> texture_state)
      : state(std::move(texture_state)) {
    texture_id = state ? state->texture_id : -1;
  }

  std::unique_ptr<State> state;
  int64_t texture_id = -1;
};

template <typename Registrar, typename State>
void RetireRegisteredTexture(Registrar* registrar,
                             std::unique_ptr<State> state) {
  if (!state) return;

  auto retirement = std::make_shared<RetiringRegisteredTexture<State>>(
      std::move(state));
  auto complete = [retirement]() mutable {
    // Resetting is idempotent, which also makes a defensive repeated callback
    // harmless while keeping the callback-captured state alive until the first
    // completion.
    retirement->state.reset();
    retirement->texture_id = -1;
  };

  if (registrar && retirement->texture_id >= 0) {
    registrar->UnregisterTexture(retirement->texture_id, std::move(complete));
    return;
  }

  // A texture that was never registered has no embedder callback to wait for.
  // This branch is only for failed registration/defensive teardown paths.
  complete();
}

}  // namespace ffmpeg_kit_extended_flutter

#endif  // FFMPEG_KIT_EXTENDED_FLUTTER_REGISTERED_TEXTURE_LIFETIME_H_
