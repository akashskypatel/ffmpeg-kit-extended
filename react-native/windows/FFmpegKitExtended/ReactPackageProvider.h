#pragma once

#include "ReactPackageProvider.g.h"

namespace winrt::FFmpegKitExtended::implementation {

struct ReactPackageProvider : ReactPackageProviderT<ReactPackageProvider> {
  ReactPackageProvider() = default;

  void CreatePackage(
      winrt::Microsoft::ReactNative::IReactPackageBuilder const &packageBuilder) noexcept;
};

} // namespace winrt::FFmpegKitExtended::implementation

namespace winrt::FFmpegKitExtended::factory_implementation {

struct ReactPackageProvider
    : ReactPackageProviderT<ReactPackageProvider, implementation::ReactPackageProvider> {};

} // namespace winrt::FFmpegKitExtended::factory_implementation
