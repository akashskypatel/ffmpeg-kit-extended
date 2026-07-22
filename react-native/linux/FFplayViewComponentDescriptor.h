#pragma once

#include <react/renderer/core/ConcreteComponentDescriptor.h>

#include "third_party/ffmpeg-kit-extended/linux/FFplayViewShadowNode.h"

namespace facebook::react {

using FFplayViewComponentDescriptor =
    ConcreteComponentDescriptor<FFplayViewShadowNode>;

} // namespace facebook::react
