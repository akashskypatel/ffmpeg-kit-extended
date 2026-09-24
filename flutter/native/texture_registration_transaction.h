#ifndef FFMPEG_KIT_EXTENDED_FLUTTER_TEXTURE_REGISTRATION_TRANSACTION_H_
#define FFMPEG_KIT_EXTENDED_FLUTTER_TEXTURE_REGISTRATION_TRANSACTION_H_

#include <cstdint>
#include <utility>

namespace ffmpeg_kit_extended_flutter {

// Completes a texture-registration transaction only after the process-global
// FFplay owner has been installed. A failed owner install unwinds the valid
// Flutter registration exactly once; an invalid registration ID never calls
// either callback.
template <typename InstallOwner, typename UnregisterTexture>
bool InstallOwnerAfterTextureRegistration(
    int64_t texture_id, InstallOwner&& install_owner,
    UnregisterTexture&& unregister_texture) {
  if (texture_id < 0) return false;
  if (!std::forward<InstallOwner>(install_owner)()) {
    std::forward<UnregisterTexture>(unregister_texture)(texture_id);
    return false;
  }
  return true;
}

// Performs plugin-owned texture teardown in the order required by the Linux
// GObject lifetime contract. A callback-held reference is outside this
// sequence and remains responsible for its own release.
template <typename UninstallOwner, typename MarkDestroyed,
          typename UnregisterTexture, typename ReleasePluginReference>
void ReleaseRegisteredTexture(UninstallOwner&& uninstall_owner,
                              MarkDestroyed&& mark_destroyed,
                              UnregisterTexture&& unregister_texture,
                              ReleasePluginReference&& release_plugin_reference) {
  std::forward<UninstallOwner>(uninstall_owner)();
  std::forward<MarkDestroyed>(mark_destroyed)();
  std::forward<UnregisterTexture>(unregister_texture)();
  std::forward<ReleasePluginReference>(release_plugin_reference)();
}

}  // namespace ffmpeg_kit_extended_flutter

#endif  // FFMPEG_KIT_EXTENDED_FLUTTER_TEXTURE_REGISTRATION_TRANSACTION_H_
