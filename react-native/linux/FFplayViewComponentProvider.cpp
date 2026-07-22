#include "third_party/ffmpeg-kit-extended/linux/FFplayViewComponentProvider.h"

#include "third_party/ffmpeg-kit-extended/linux/FFplayViewComponent.h"
#include "third_party/ffmpeg-kit-extended/linux/FFplayViewComponentDescriptor.h"

namespace facebook::react {

ComponentDescriptorProvider
FFplayViewComponentProvider::GetDescriptorProvider() {
  return concreteComponentDescriptorProvider<FFplayViewComponentDescriptor>();
}

std::shared_ptr<RSkComponent> FFplayViewComponentProvider::CreateComponent(
    const ShadowView &shadowView) {
  return std::static_pointer_cast<RSkComponent>(
      std::make_shared<FFplayViewComponent>(shadowView));
}

} // namespace facebook::react
