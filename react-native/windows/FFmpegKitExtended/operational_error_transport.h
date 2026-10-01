#pragma once

#include <string>
#include <utility>

namespace winrt::FFmpegKitExtended {

// RNW requires every native module method to be noexcept, including methods
// whose shared adapter can report ordinary runtime, argument, or session
// failures. Keep one error per calling thread so the JS proxy can consume it
// immediately after the native method returns.
inline thread_local std::string lastOperationalError;

inline void clearOperationalError() noexcept {
  lastOperationalError.clear();
}

inline void recordOperationalError(const char *method,
                                   const char *message) noexcept {
  try {
    lastOperationalError = "FFmpegKitExtended Windows native call failed in ";
    lastOperationalError += method ? method : "unknown method";
    lastOperationalError += ": ";
    lastOperationalError += message ? message : "unknown native error";
  } catch (...) {
    // Error reporting must never become a second exception at the noexcept
    // boundary. An empty result still leaves the host process alive.
    lastOperationalError.clear();
  }
}

inline std::string consumeOperationalError() noexcept {
  std::string result = std::move(lastOperationalError);
  lastOperationalError.clear();
  return result;
}

}  // namespace winrt::FFmpegKitExtended
