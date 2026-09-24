#include "../../native/texture_registration_transaction.h"

#include <glib-object.h>

#include <cassert>
#include <cstdint>

namespace {

struct FinalizationObservation {
  int count = 0;
};

void on_finalized(gpointer user_data, GObject*) {
  auto* observation = static_cast<FinalizationObservation*>(user_data);
  ++observation->count;
}

GObject* new_observed_object(FinalizationObservation* observation) {
  auto* object = G_OBJECT(g_object_new(G_TYPE_OBJECT, nullptr));
  g_object_weak_ref(object, on_finalized, observation);
  return object;
}

}  // namespace

int main() {
  using ffmpeg_kit_extended_flutter::InstallOwnerAfterTextureRegistration;
  using ffmpeg_kit_extended_flutter::ReleaseRegisteredTexture;

  // A registrar failure never acquires a registrar reference, so the
  // plugin-owned reference is the only reference that must be released.
  {
    FinalizationObservation observation;
    GObject* object = new_observed_object(&observation);
    int owner_install_calls = 0;
    assert(!InstallOwnerAfterTextureRegistration(
        -1,
        [&] {
          ++owner_install_calls;
          return true;
        },
        [&](int64_t) { assert(false); }));
    assert(owner_install_calls == 0);
    g_object_unref(object);
    assert(observation.count == 1);
  }

  // A failed owner install after registration releases both long-lived refs.
  {
    FinalizationObservation observation;
    GObject* object = new_observed_object(&observation);
    g_object_ref(object);  // Flutter registrar reference.
    assert(!InstallOwnerAfterTextureRegistration(
        42, [] { return false; }, [&](int64_t texture_id) {
          assert(texture_id == 42);
          g_object_unref(object);  // Flutter registrar reference.
          g_object_unref(object);  // Plugin-owned reference.
        }));
    assert(observation.count == 1);
  }

  // Plugin disposal releases its own reference while an already queued idle
  // callback keeps the object alive and releases its independent reference
  // later.
  {
    FinalizationObservation observation;
    GObject* object = new_observed_object(&observation);
    g_object_ref(object);  // Flutter registrar reference.
    g_object_ref(object);  // Queued idle callback reference.
    ReleaseRegisteredTexture(
        [] {}, [] {}, [&] { g_object_unref(object); },
        [&] { g_object_unref(object); });
    assert(observation.count == 0);
    g_object_unref(object);  // Queued idle callback completes.
    assert(observation.count == 1);
  }

  return 0;
}
