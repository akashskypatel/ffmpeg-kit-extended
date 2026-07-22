#include "pch.h"

#include "ReactPackageProvider.h"
#if __has_include("ReactPackageProvider.g.cpp")
#include "ReactPackageProvider.g.cpp"
#endif

#include "FFmpegKitExtended.h"
#include "FFplayView.h"

using namespace winrt::Microsoft::ReactNative;

namespace winrt::FFmpegKitExtended::implementation {

void ReactPackageProvider::CreatePackage(
    IReactPackageBuilder const &packageBuilder) noexcept {
  AddAttributedModules(packageBuilder, true);
  RegisterFFplayViewNativeComponent(packageBuilder);
}

} // namespace winrt::FFmpegKitExtended::implementation
