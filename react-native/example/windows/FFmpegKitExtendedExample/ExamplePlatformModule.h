#pragma once

#include "NativeModules.h"

#include <string>

namespace winrt::FFmpegKitExtendedExample {

REACT_MODULE(ExamplePlatformModule, L"FFmpegKitExtendedExamplePlatform")
struct ExamplePlatformModule {
  REACT_SYNC_METHOD(getExampleDirectory)
  std::string getExampleDirectory() noexcept;

  REACT_METHOD(ensureDirectory)
  void ensureDirectory(std::string path) noexcept;

  REACT_SYNC_METHOD(fileExists)
  bool fileExists(std::string path) noexcept;

  REACT_METHOD(removeFile)
  void removeFile(std::string path) noexcept;

  REACT_METHOD(writeTextFile)
  void writeTextFile(std::string path, std::string contents) noexcept;

  REACT_METHOD(appendTextFile)
  void appendTextFile(std::string path, std::string contents) noexcept;

  REACT_SYNC_METHOD(basename)
  std::string basename(std::string path) noexcept;

  REACT_SYNC_METHOD(pickLocalFile)
  std::string pickLocalFile(bool videoOnly) noexcept;
};

} // namespace winrt::FFmpegKitExtendedExample
