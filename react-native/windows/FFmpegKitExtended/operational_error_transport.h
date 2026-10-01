#pragma once

#include <string>
#include <utility>

namespace winrt::FFmpegKitExtended {

// Synchronous RNW getters still need a same-call scalar-result diagnostic
// because their generated contract cannot carry a Promise. Asynchronous
// actions never write this channel; they reject their invocation-bound Promise
// directly.
inline thread_local std::string synchronousOperationalError;

inline void clearSynchronousError() noexcept {
  synchronousOperationalError.clear();
}

inline void recordSynchronousError(const char *method,
                                   const char *message) noexcept {
  try {
    synchronousOperationalError = "FFmpegKitExtended Windows synchronous call failed in ";
    synchronousOperationalError += method ? method : "unknown method";
    synchronousOperationalError += ": ";
    synchronousOperationalError += message ? message : "unknown native error";
  } catch (...) {
    synchronousOperationalError.clear();
  }
}

inline std::string consumeSynchronousErrorValue() noexcept {
  std::string result = std::move(synchronousOperationalError);
  synchronousOperationalError.clear();
  return result;
}

}  // namespace winrt::FFmpegKitExtended
