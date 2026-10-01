#pragma once

#include "operational_error_transport.h"

#include <string>
#include <stdexcept>
#include <utility>

namespace winrt::FFmpegKitExtended {

// This seam is process-local and never changes the frozen native ABI. It lets
// the native boundary oracle inject ordinary adapter failures without
// modifying or corrupting the real runtime DLL.
enum class DispatchFailure {
  none,
  runtimeUnavailable,
  requiredSymbolUnavailable,
  invalidCreateArguments,
  sessionCreationFailure,
  sessionNotFound,
  wrongFfplayTarget,
};

inline thread_local DispatchFailure injectedDispatchFailure = DispatchFailure::none;

inline void setInjectedDispatchFailureForTesting(DispatchFailure failure) noexcept {
  injectedDispatchFailure = failure;
}

inline void clearInjectedDispatchFailureForTesting() noexcept {
  injectedDispatchFailure = DispatchFailure::none;
}

inline void throwInjectedDispatchFailure(const char *method) {
  const DispatchFailure failure = injectedDispatchFailure;
  injectedDispatchFailure = DispatchFailure::none;

  const char *reason = nullptr;
  switch (failure) {
    case DispatchFailure::none:
      return;
    case DispatchFailure::runtimeUnavailable:
      reason = "runtime unavailable";
      break;
    case DispatchFailure::requiredSymbolUnavailable:
      reason = "required symbol unavailable";
      break;
    case DispatchFailure::invalidCreateArguments:
      reason = "invalid create arguments";
      break;
    case DispatchFailure::sessionCreationFailure:
      reason = "session creation failure";
      break;
    case DispatchFailure::sessionNotFound:
      reason = "session not found";
      break;
    case DispatchFailure::wrongFfplayTarget:
      reason = "wrong FFplay target";
      break;
  }

  throw std::runtime_error(
      std::string(method ? method : "unknown method") + ": " + reason);
}

template <typename Reject>
void rejectInvocation(const char *method, const char *message,
                      Reject &&reject) noexcept {
  try {
    std::string qualified = "FFmpegKitExtended Windows native call failed in ";
    qualified += method ? method : "unknown method";
    qualified += ": ";
    qualified += message ? message : "unknown native error";
    std::forward<Reject>(reject)(qualified.c_str());
  } catch (...) {
    try {
      std::forward<Reject>(reject)(
          "FFmpegKitExtended Windows native call failed: error formatting failed");
    } catch (...) {
    }
  }
}

template <typename Fn, typename Resolve, typename Reject>
void invokeWithCompletion(const char *method, Fn &&fn, Resolve &&resolve,
                          Reject &&reject) noexcept {
  try {
    throwInjectedDispatchFailure(method);
    std::forward<Fn>(fn)();
    std::forward<Resolve>(resolve)();
  } catch (const std::exception &error) {
    rejectInvocation(method, error.what(), std::forward<Reject>(reject));
  } catch (...) {
    rejectInvocation(method, "non-standard exception", std::forward<Reject>(reject));
  }
}

template <typename Fn>
void invokeSynchronous(const char *method, Fn &&fn) noexcept {
  clearSynchronousError();
  try {
    throwInjectedDispatchFailure(method);
    std::forward<Fn>(fn)();
  } catch (const std::exception &error) {
    recordSynchronousError(method, error.what());
  } catch (...) {
    recordSynchronousError(method, "non-standard exception");
  }
}

template <typename Result, typename Fn>
Result invokeSynchronous(const char *method, Fn &&fn) noexcept {
  clearSynchronousError();
  try {
    throwInjectedDispatchFailure(method);
    return std::forward<Fn>(fn)();
  } catch (const std::exception &error) {
    recordSynchronousError(method, error.what());
  } catch (...) {
    recordSynchronousError(method, "non-standard exception");
  }
  return Result{};
}

}  // namespace winrt::FFmpegKitExtended
