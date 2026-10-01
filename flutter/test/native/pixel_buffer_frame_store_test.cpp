#include "../../native/pixel_buffer_frame_store.h"

#include <cassert>
#include <cstdint>

namespace {

void AssertFirstRenderAndProducerIsolation() {
  ffmpeg_kit_extended_flutter::PixelBufferFrameStore store;
  const uint8_t first[] = {1, 2, 3, 4};
  store.publish(first, sizeof(first), 1, 1);

  const uint8_t* buffer = nullptr;
  uint32_t width = 0;
  uint32_t height = 0;
  assert(store.copyForRender(&buffer, &width, &height));
  assert(buffer[0] == 1 && buffer[3] == 4);
  assert(width == 1 && height == 1);

  const uint8_t second[] = {5, 6, 7, 8};
  store.publish(second, sizeof(second), 1, 1);
  assert(buffer[0] == 1 && buffer[3] == 4);
  assert(store.copyForRender(&buffer, &width, &height));
  assert(buffer[0] == 5 && buffer[3] == 8);
}

void AssertReleaseReuseAndFinalLifetime() {
  ffmpeg_kit_extended_flutter::PixelBufferFrameStore store;
  const uint8_t frame[] = {9, 10, 11, 12};
  store.publish(frame, sizeof(frame), 1, 1);

  const uint8_t* render_buffer = nullptr;
  uint32_t width = 0;
  uint32_t height = 0;
  assert(store.copyForRender(&render_buffer, &width, &height));
  assert(store.renderBufferSize() == sizeof(frame));

  store.markDestroyed();
  assert(store.destroyed());
  assert(!store.copyForRender(&render_buffer, &width, &height));
  assert(store.renderBufferSize() == sizeof(frame));

  store.resetForReuse();
  assert(!store.destroyed());
  const uint8_t reused[] = {13, 14, 15, 16};
  store.publish(reused, sizeof(reused), 1, 1);
  assert(store.copyForRender(&render_buffer, &width, &height));
  assert(render_buffer[0] == 13 && render_buffer[3] == 16);

  store.markDestroyed();
  store.clearAfterUnregister();
  assert(store.renderBufferSize() == 0);
}

void AssertNeverPopulatedRetiresCleanly() {
  ffmpeg_kit_extended_flutter::PixelBufferFrameStore store;
  const uint8_t* buffer = nullptr;
  uint32_t width = 0;
  uint32_t height = 0;
  assert(store.copyForRender(&buffer, &width, &height));
  assert(buffer[3] == 255);
  store.markDestroyed();
  store.clearAfterUnregister();
  assert(store.renderBufferSize() == 0);
}

}  // namespace

int main() {
  AssertFirstRenderAndProducerIsolation();
  AssertReleaseReuseAndFinalLifetime();
  AssertNeverPopulatedRetiresCleanly();
  return 0;
}
