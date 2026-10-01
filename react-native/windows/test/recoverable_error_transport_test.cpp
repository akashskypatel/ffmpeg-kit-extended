#include "../FFmpegKitExtended/recoverable_native_dispatch.h"

#include <cassert>
#include <string>

namespace {

using winrt::FFmpegKitExtended::DispatchFailure;
using winrt::FFmpegKitExtended::clearInjectedDispatchFailureForTesting;
using winrt::FFmpegKitExtended::consumeOperationalError;
using winrt::FFmpegKitExtended::invokeRecoverably;
using winrt::FFmpegKitExtended::setInjectedDispatchFailureForTesting;

void assertInjectedFailure(DispatchFailure failure, const char *expected) {
  setInjectedDispatchFailureForTesting(failure);
  const int result = invokeRecoverably<int>("createFFmpegSession", [] {
    return 42;
  });
  assert(result == 0);

  const std::string message = consumeOperationalError();
  assert(message.find(expected) != std::string::npos);

  // A second boundary call proves the exception did not escape or poison the
  // host thread. Successful values remain unchanged.
  assert(invokeRecoverably<int>("createFFmpegSession", [] { return 42; }) ==
         42);
  assert(consumeOperationalError().empty());
}

}  // namespace

int main() {
  using winrt::FFmpegKitExtended::recordOperationalError;

  clearInjectedDispatchFailureForTesting();
  assert(consumeOperationalError().empty());

  assertInjectedFailure(DispatchFailure::runtimeUnavailable,
                        "runtime unavailable");
  assertInjectedFailure(DispatchFailure::requiredSymbolUnavailable,
                        "required symbol unavailable");
  assertInjectedFailure(DispatchFailure::invalidCreateArguments,
                        "invalid create arguments");
  assertInjectedFailure(DispatchFailure::sessionCreationFailure,
                        "session creation failure");
  assertInjectedFailure(DispatchFailure::sessionNotFound, "session not found");
  assertInjectedFailure(DispatchFailure::wrongFfplayTarget,
                        "wrong FFplay target");

  recordOperationalError("createFFmpegSession", "invalid argument list");
  const std::string first = consumeOperationalError();
  assert(first.find("createFFmpegSession") != std::string::npos);
  assert(first.find("invalid argument list") != std::string::npos);
  assert(consumeOperationalError().empty());

  recordOperationalError("getSessionState", "session ID not found");
  recordOperationalError("getSessionState", "replacement error");
  assert(consumeOperationalError().find("replacement error") !=
         std::string::npos);
  assert(consumeOperationalError().empty());
  return 0;
}
