#include <flutter/method_call.h>
#include <flutter/method_result_functions.h>
#include <flutter/standard_method_codec.h>
#include <gtest/gtest.h>
#include <windows.h>

#include <memory>
#include <string>
#include <variant>

#include "ffmpeg_kit_flutter_plugin.h"

namespace ffmpeg_kit_extended_flutter {
namespace test {

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;
using flutter::MethodCall;
using flutter::MethodResultFunctions;

} // namespace

TEST(FfmpegKitFlutterPlugin, GetPlatform) {
  FfmpegKitFlutterPlugin plugin(nullptr);
  // Save the reply value from the success callback.
  std::string result_string;
  plugin.HandleMethodCall(
      MethodCall("getPlatform", std::make_unique<EncodableValue>()),
      std::make_unique<MethodResultFunctions<>>(
          [&result_string](const EncodableValue *result) {
            result_string = std::get<std::string>(*result);
          },
          nullptr, nullptr));

  // The implementation returns "windows"
  EXPECT_EQ(result_string, "windows");
}

} // namespace test
} // namespace ffmpeg_kit_extended_flutter
