#include "pch.h"
#include "FFmpegKitExtendedExample.h"

#include "AutolinkedNativeModules.g.h"
#include "ExamplePlatformModule.h"
#include "NativeModules.h"

#include <appmodel.h>
#include <string>
#include <vector>

struct CompReactPackageProvider
    : winrt::implements<CompReactPackageProvider,
                        winrt::Microsoft::ReactNative::IReactPackageProvider> {
  void CreatePackage(
      winrt::Microsoft::ReactNative::IReactPackageBuilder const &packageBuilder) noexcept {
    AddAttributedModules(packageBuilder, true);
  }
};

_Use_decl_annotations_ int CALLBACK WinMain(HINSTANCE instance,
                                             HINSTANCE,
                                             PSTR,
                                             int) {
  UNREFERENCED_PARAMETER(instance);
  winrt::init_apartment(winrt::apartment_type::single_threaded);
  SetProcessDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2);

  WCHAR appDirectory[MAX_PATH]{};
  GetModuleFileNameW(nullptr, appDirectory, MAX_PATH);
  PathCchRemoveFileSpec(appDirectory, MAX_PATH);

  auto app = winrt::Microsoft::ReactNative::ReactNativeAppBuilder().Build();
  auto settings = app.ReactNativeHost().InstanceSettings();
  winrt::Microsoft::ReactNative::RegisterAutolinkedNativeModulePackages(
      settings.PackageProviders());
  settings.PackageProviders().Append(winrt::make<CompReactPackageProvider>());

  UINT32 packagePathLength = 0;
  std::wstring bundleRootPath;
  if (GetCurrentPackagePath(&packagePathLength, nullptr) ==
      ERROR_INSUFFICIENT_BUFFER) {
    std::vector<wchar_t> packagePath(packagePathLength);
    if (GetCurrentPackagePath(&packagePathLength, packagePath.data()) ==
        ERROR_SUCCESS) {
      bundleRootPath.assign(packagePath.data());
      if (!bundleRootPath.empty() && bundleRootPath.back() != L'\\') {
        bundleRootPath.push_back(L'\\');
      }
      bundleRootPath.append(L"Bundle\\");
    }
  }

  if (!bundleRootPath.empty()) {
    // RNW resolves non-resource bundle roots as filesystem paths. Passing an
    // ms-appx URI here would be treated as a literal path by the local bundle
    // reader in the RNW version used by this example.
    settings.BundleRootPath(bundleRootPath.c_str());
  } else {
    settings.BundleRootPath(
        std::wstring(appDirectory).append(L"\\Bundle\\").c_str());
  }
  settings.JavaScriptBundleFile(L"index.windows");
  settings.DebugBundlePath(L"index");

#if BUNDLE
  settings.UseFastRefresh(false);
#else
  settings.UseFastRefresh(true);
#endif

#if _DEBUG
  settings.UseDirectDebugger(true);
  settings.UseDeveloperSupport(true);
#else
  settings.UseDirectDebugger(false);
  settings.UseDeveloperSupport(false);
#endif

  auto appWindow = app.AppWindow();
  appWindow.Title(L"FFmpegKit Extended React Native Example");
  appWindow.Resize({1200, 900});

  auto viewOptions = app.ReactViewOptions();
  viewOptions.ComponentName(L"FFmpegKitExtendedExample");

  app.Start();
  return 0;
}
