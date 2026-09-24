#include "../../native/texture_registration_transaction.h"

#include <cassert>
#include <cstdint>
#include <string>

int main() {
  using ffmpeg_kit_extended_flutter::InstallOwnerAfterTextureRegistration;
  using ffmpeg_kit_extended_flutter::ReleaseRegisteredTexture;

  int install_calls = 0;
  int unregister_calls = 0;

  assert(!InstallOwnerAfterTextureRegistration(
      -1, [&] {
        ++install_calls;
        return true;
      },
      [&](int64_t) { ++unregister_calls; }));
  assert(install_calls == 0);
  assert(unregister_calls == 0);

  assert(!InstallOwnerAfterTextureRegistration(
      7, [&] {
        ++install_calls;
        return false;
      },
      [&](int64_t texture_id) {
        assert(texture_id == 7);
        ++unregister_calls;
      }));
  assert(install_calls == 1);
  assert(unregister_calls == 1);

  assert(InstallOwnerAfterTextureRegistration(
      8, [&] {
        ++install_calls;
        return true;
      },
      [&](int64_t) { ++unregister_calls; }));
  assert(install_calls == 2);
  assert(unregister_calls == 1);

  std::string order;
  int plugin_releases = 0;
  ReleaseRegisteredTexture(
      [&] { order += 'U'; }, [&] { order += 'D'; }, [&] { order += 'R'; },
      [&] {
        order += 'X';
        ++plugin_releases;
      });
  assert(order == "UDRX");
  assert(plugin_releases == 1);
  return 0;
}
