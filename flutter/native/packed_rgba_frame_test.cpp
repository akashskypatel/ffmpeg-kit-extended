#include "packed_rgba_frame.h"

#include <cassert>
#include <cstdint>
#include <vector>

namespace {

using ffmpeg_kit_extended_flutter::NormalizePackedRgbaFrame;
using ffmpeg_kit_extended_flutter::PackedRgbaFrame;

void expectLayout(const char* format, const std::vector<std::uint8_t>& source,
                  const std::vector<std::uint8_t>& expected) {
  PackedRgbaFrame frame;
  assert(NormalizePackedRgbaFrame(source.data(), 2, 2, 12, format, &frame));
  assert(frame.width == 2);
  assert(frame.height == 2);
  assert(frame.bytes == expected);
}

} // namespace

int main() {
  // Two rows with four bytes of decoder padding after each active row.
  const std::vector<std::uint8_t> rgba = {
      1, 2, 3, 4, 5, 6, 7, 8, 99, 98, 97, 96,
      11, 12, 13, 14, 15, 16, 17, 18, 95, 94, 93, 92,
  };
  expectLayout("rgba", rgba, {1, 2, 3, 4, 5, 6, 7, 8,
                               11, 12, 13, 14, 15, 16, 17, 18});
  expectLayout("rgb0", rgba, {1, 2, 3, 255, 5, 6, 7, 255,
                               11, 12, 13, 255, 15, 16, 17, 255});

  const std::vector<std::uint8_t> bgra = {
      3, 2, 1, 4, 7, 6, 5, 8, 0, 0, 0, 0,
      13, 12, 11, 14, 17, 16, 15, 18, 0, 0, 0, 0,
  };
  expectLayout("bgra", bgra, {1, 2, 3, 4, 5, 6, 7, 8,
                               11, 12, 13, 14, 15, 16, 17, 18});
  expectLayout("bgr0", bgra, {1, 2, 3, 255, 5, 6, 7, 255,
                               11, 12, 13, 255, 15, 16, 17, 255});

  const std::vector<std::uint8_t> argb = {
      4, 1, 2, 3, 8, 5, 6, 7, 0, 0, 0, 0,
      14, 11, 12, 13, 18, 15, 16, 17, 0, 0, 0, 0,
  };
  expectLayout("argb", argb, {1, 2, 3, 4, 5, 6, 7, 8,
                               11, 12, 13, 14, 15, 16, 17, 18});

  const std::vector<std::uint8_t> abgr = {
      4, 3, 2, 1, 8, 7, 6, 5, 0, 0, 0, 0,
      14, 13, 12, 11, 18, 17, 16, 15, 0, 0, 0, 0,
  };
  expectLayout("abgr", abgr, {1, 2, 3, 4, 5, 6, 7, 8,
                               11, 12, 13, 14, 15, 16, 17, 18});

  PackedRgbaFrame unchanged;
  unchanged.bytes = {42};
  assert(!NormalizePackedRgbaFrame(rgba.data(), 2, 2, 7, "rgba", &unchanged));
  assert(unchanged.bytes == std::vector<std::uint8_t>{42});
  assert(!NormalizePackedRgbaFrame(rgba.data(), 2, 2, 12, "yuv420p", &unchanged));
  assert(!NormalizePackedRgbaFrame(rgba.data(), 0, 2, 12, "rgba", &unchanged));
  assert(!NormalizePackedRgbaFrame(rgba.data(), 2, 2, 12, nullptr, &unchanged));
  return 0;
}
