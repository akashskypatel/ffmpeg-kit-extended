#pragma once

#include <react/renderer/components/view/ConcreteViewShadowNode.h>
#include <react/renderer/components/view/ViewProps.h>

namespace facebook::react {

extern const char FFplayViewComponentName[];

using FFplayViewShadowNode =
    ConcreteViewShadowNode<FFplayViewComponentName, ViewProps>;

} // namespace facebook::react
