#pragma once

#include "ReactSkia/components/RSkComponentProvider.h"

namespace facebook::react {

class FFplayViewComponentProvider final : public RSkComponentProvider {
 public:
  ComponentDescriptorProvider GetDescriptorProvider() override;
  std::shared_ptr<RSkComponent> CreateComponent(
      const ShadowView &shadowView) override;
};

} // namespace facebook::react
