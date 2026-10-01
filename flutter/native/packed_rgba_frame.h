#pragma once

#include <cstddef>
#include <cstdint>
#include <limits>
#include <string_view>
#include <utility>
#include <vector>

namespace ffmpeg_kit_extended_flutter {

/** A tightly packed, canonical RGBA8888 frame ready for Flutter textures. */
struct PackedRgbaFrame {
  std::vector<std::uint8_t> bytes;
  std::uint32_t width = 0;
  std::uint32_t height = 0;
};

/**
 * Converts one FFplay frame into tightly packed RGBA8888 pixels.
 *
 * FFplay's supported four-byte layouts are accepted explicitly. Only the
 * active width is copied from each source row, so decoder padding is never
 * exposed to Flutter's pixel-buffer contract.
 */
inline bool NormalizePackedRgbaFrame(const std::uint8_t* pixels, int width,
                                     int height, int linesize,
                                     const char* pixel_format,
                                     PackedRgbaFrame* output) {
  if (pixels == nullptr || output == nullptr || pixel_format == nullptr ||
      width <= 0 || height <= 0 || linesize <= 0) {
    return false;
  }

  const auto format = std::string_view(pixel_format);
  const bool rgba = format == "rgba";
  const bool rgb0 = format == "rgb0";
  const bool bgra = format == "bgra";
  const bool bgr0 = format == "bgr0";
  const bool argb = format == "argb";
  const bool abgr = format == "abgr";
  if (!rgba && !rgb0 && !bgra && !bgr0 && !argb && !abgr) return false;

  const auto width_value = static_cast<std::size_t>(width);
  const auto height_value = static_cast<std::size_t>(height);
  if (width_value > (std::numeric_limits<std::size_t>::max)() / 4) {
    return false;
  }
  const auto row_bytes = width_value * 4;
  if (static_cast<std::size_t>(linesize) < row_bytes ||
       height_value > (std::numeric_limits<std::size_t>::max)() / row_bytes) {
    return false;
  }

  PackedRgbaFrame normalized;
  normalized.bytes.resize(row_bytes * height_value);
  normalized.width = static_cast<std::uint32_t>(width);
  normalized.height = static_cast<std::uint32_t>(height);

  for (std::size_t y = 0; y < height_value; ++y) {
    const auto* source = pixels + y * static_cast<std::size_t>(linesize);
    auto* destination = normalized.bytes.data() + y * row_bytes;
    for (std::size_t x = 0; x < width_value; ++x) {
      const auto* source_pixel = source + x * 4;
      auto* destination_pixel = destination + x * 4;
      if (rgba || rgb0) {
        destination_pixel[0] = source_pixel[0];
        destination_pixel[1] = source_pixel[1];
        destination_pixel[2] = source_pixel[2];
        destination_pixel[3] = rgba ? source_pixel[3] : 0xff;
      } else if (bgra || bgr0) {
        destination_pixel[0] = source_pixel[2];
        destination_pixel[1] = source_pixel[1];
        destination_pixel[2] = source_pixel[0];
        destination_pixel[3] = bgra ? source_pixel[3] : 0xff;
      } else if (argb) {
        destination_pixel[0] = source_pixel[1];
        destination_pixel[1] = source_pixel[2];
        destination_pixel[2] = source_pixel[3];
        destination_pixel[3] = source_pixel[0];
      } else { // abgr
        destination_pixel[0] = source_pixel[3];
        destination_pixel[1] = source_pixel[2];
        destination_pixel[2] = source_pixel[1];
        destination_pixel[3] = source_pixel[0];
      }
    }
  }

  *output = std::move(normalized);
  return true;
}

} // namespace ffmpeg_kit_extended_flutter
