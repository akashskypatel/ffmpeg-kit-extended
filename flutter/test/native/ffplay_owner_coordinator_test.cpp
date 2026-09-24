#include "../../native/ffplay_owner_coordinator.h"

#include <cassert>

struct OwnerToken {};

int main() {
  ffmpeg_kit_extended_flutter::FfplayOwnerCoordinator<OwnerToken> coordinator;
  OwnerToken first;
  OwnerToken second;
  int install_calls = 0;
  int uninstall_calls = 0;

  assert(coordinator.install(&first, [&] { ++install_calls; }));
  assert(coordinator.install(&second, [&] { ++install_calls; }));
  assert(!coordinator.uninstallIfOwned(&first, [&] { ++uninstall_calls; }));
  assert(coordinator.isOwner(&second));
  assert(coordinator.uninstallIfOwned(&second, [&] { ++uninstall_calls; }));
  assert(!coordinator.isOwner(&second));
  assert(install_calls == 2);
  assert(uninstall_calls == 1);
  return 0;
}
