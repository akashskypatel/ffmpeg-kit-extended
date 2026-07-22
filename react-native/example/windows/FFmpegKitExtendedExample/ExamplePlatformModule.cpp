#include "pch.h"
#include "ExamplePlatformModule.h"

#include <commdlg.h>

#include <filesystem>
#include <fstream>

namespace winrt::FFmpegKitExtendedExample {
namespace {

std::filesystem::path ToPath(const std::string &path) {
  return std::filesystem::path(winrt::to_hstring(path).c_str());
}

std::string ToUtf8(const std::filesystem::path &path) {
  return winrt::to_string(winrt::hstring(path.wstring()));
}

std::filesystem::path ExampleDirectory() {
  wchar_t buffer[MAX_PATH]{};
  DWORD length = GetTempPathW(MAX_PATH, buffer);
  if (length == 0 || length >= MAX_PATH) {
    return std::filesystem::temp_directory_path() /
           L"ffmpeg_kit_extended_react_native_example";
  }
  return std::filesystem::path(buffer) /
         L"ffmpeg_kit_extended_react_native_example";
}

void EnsureParent(const std::filesystem::path &path) {
  const auto parent = path.parent_path();
  if (!parent.empty()) {
    std::filesystem::create_directories(parent);
  }
}

} // namespace

std::string ExamplePlatformModule::getExampleDirectory() noexcept {
  try {
    const auto path = ExampleDirectory();
    std::filesystem::create_directories(path);
    return ToUtf8(path);
  } catch (...) {
    return {};
  }
}

void ExamplePlatformModule::ensureDirectory(std::string path) noexcept {
  try {
    std::filesystem::create_directories(ToPath(path));
  } catch (...) {
  }
}

bool ExamplePlatformModule::fileExists(std::string path) noexcept {
  try {
    return std::filesystem::exists(ToPath(path));
  } catch (...) {
    return false;
  }
}

void ExamplePlatformModule::removeFile(std::string path) noexcept {
  try {
    std::filesystem::remove(ToPath(path));
  } catch (...) {
  }
}

void ExamplePlatformModule::writeTextFile(std::string path,
                                          std::string contents) noexcept {
  try {
    const auto target = ToPath(path);
    EnsureParent(target);
    std::ofstream stream(target, std::ios::binary | std::ios::trunc);
    stream.write(contents.data(), static_cast<std::streamsize>(contents.size()));
  } catch (...) {
  }
}

void ExamplePlatformModule::appendTextFile(std::string path,
                                           std::string contents) noexcept {
  try {
    const auto target = ToPath(path);
    EnsureParent(target);
    std::ofstream stream(target, std::ios::binary | std::ios::app);
    stream.write(contents.data(), static_cast<std::streamsize>(contents.size()));
  } catch (...) {
  }
}

std::string ExamplePlatformModule::basename(std::string path) noexcept {
  try {
    return ToUtf8(ToPath(path).filename());
  } catch (...) {
    return path;
  }
}

std::string ExamplePlatformModule::pickLocalFile(bool videoOnly) noexcept {
  try {
    wchar_t filePath[32768]{};
    const wchar_t *filter = videoOnly
        ? L"Video files\0*.mp4;*.mkv;*.mov;*.avi;*.webm;*.m4v;*.ts;*.m2ts\0All files\0*.*\0\0"
        : L"Media files\0*.mp4;*.mkv;*.mov;*.avi;*.webm;*.m4v;*.ts;*.m2ts;*.mp3;*.m4a;*.aac;*.wav;*.flac;*.ogg\0All files\0*.*\0\0";

    OPENFILENAMEW dialog{};
    dialog.lStructSize = sizeof(dialog);
    dialog.lpstrFile = filePath;
    dialog.nMaxFile = static_cast<DWORD>(_countof(filePath));
    dialog.lpstrFilter = filter;
    dialog.nFilterIndex = 1;
    dialog.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST |
                   OFN_EXPLORER | OFN_NOCHANGEDIR;

    if (!GetOpenFileNameW(&dialog)) {
      return {};
    }
    return winrt::to_string(winrt::hstring(filePath));
  } catch (...) {
    return {};
  }
}

} // namespace winrt::FFmpegKitExtendedExample
