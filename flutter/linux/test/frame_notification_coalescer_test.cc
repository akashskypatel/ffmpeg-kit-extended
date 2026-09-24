#include "../../native/frame_notification_coalescer.h"

#include <glib.h>

#include <cassert>

namespace {

struct NotificationHarness {
  ffmpeg_kit_extended_flutter::FrameNotificationCoalescer notification;
  int latest_frame = 0;
  int marked_frame = 0;
  int mark_count = 0;
  int queued_sources = 0;
  int callback_refs = 0;
  int max_queued_sources = 0;
  int max_callback_refs = 0;
};

gboolean consume_mark(gpointer user_data) {
  auto* harness = static_cast<NotificationHarness*>(user_data);
  --harness->queued_sources;
  --harness->callback_refs;
  harness->notification.consume();
  ++harness->mark_count;
  harness->marked_frame = harness->latest_frame;
  return G_SOURCE_REMOVE;
}

void submit_frame(NotificationHarness* harness, int frame) {
  harness->latest_frame = frame;
  if (!harness->notification.request()) return;

  ++harness->queued_sources;
  ++harness->callback_refs;
  harness->max_queued_sources =
      MAX(harness->max_queued_sources, harness->queued_sources);
  harness->max_callback_refs =
      MAX(harness->max_callback_refs, harness->callback_refs);
  g_idle_add(consume_mark, harness);
}

void drain_default_context() {
  while (g_main_context_pending(nullptr)) {
    g_main_context_iteration(nullptr, FALSE);
  }
}

}  // namespace

int main() {
  NotificationHarness harness;

  for (int frame = 1; frame <= 1000; ++frame) {
    submit_frame(&harness, frame);
  }

  assert(harness.queued_sources == 1);
  assert(harness.callback_refs == 1);
  assert(harness.max_queued_sources == 1);
  assert(harness.max_callback_refs == 1);
  assert(harness.latest_frame == 1000);
  assert(harness.mark_count == 0);
  assert(harness.notification.isPending());

  drain_default_context();

  assert(harness.queued_sources == 0);
  assert(harness.callback_refs == 0);
  assert(harness.mark_count == 1);
  assert(harness.marked_frame == 1000);
  assert(!harness.notification.isPending());

  submit_frame(&harness, 1001);
  assert(harness.queued_sources == 1);
  assert(harness.callback_refs == 1);
  assert(harness.notification.isPending());

  drain_default_context();

  assert(harness.queued_sources == 0);
  assert(harness.callback_refs == 0);
  assert(harness.mark_count == 2);
  assert(harness.marked_frame == 1001);
  assert(!harness.notification.isPending());
  return 0;
}
