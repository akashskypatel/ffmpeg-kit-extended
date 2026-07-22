#pragma once

#include <memory>
#include <string>

#include "ReactCommon/TurboModule.h"

namespace facebook::react {

class FFmpegKitExtendedTurboModule final : public TurboModule {
 public:
  FFmpegKitExtendedTurboModule(
      const std::string &name,
      std::shared_ptr<CallInvoker> jsInvoker);
};

} // namespace facebook::react
