#include "FFmpegKitDynamicApi.h"

#include <array>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <cstring>
#include <exception>
#include <mutex>
#include <stdexcept>
#include <string>
#include <thread>

namespace {

struct FakeSession {
  bool created = false;
  bool visible = false;
  std::int64_t id = 0;
  int state = 2;
};

std::array<FakeSession, 32> sessions{};
std::mutex fakeMutex;
std::condition_variable fakeCondition;
std::int64_t nextCreatedId = 8;
int nextCreatedState = 2;
std::int64_t pauseSerializationId = 0;
std::int64_t blockedStateId = 0;
std::int64_t secondRecordId = 0;
bool allowSerialization = false;
bool allowStateRead = false;
bool serializationEntered = false;
bool stateReadEntered = false;
bool secondRecordReached = false;
bool historyFinished = false;
bool clearCalled = false;
bool blockNativeClear = false;
bool nativeClearEntered = false;
bool allowNativeClear = false;
bool failNextClear = false;
bool rejectHistoryLookup = false;
bool historyLookupCrossedBarrier = false;
std::exception_ptr historyError;
std::exception_ptr clearError;

FakeSession &sessionFor(void *handle) {
  return *static_cast<FakeSession *>(handle);
}

void fakeInitialize() {}
void fakeFree(void *) {}

void fakeRelease(void *) {}

void *fakeGetSession(std::int64_t id) {
  if (id <= 0 || id >= static_cast<std::int64_t>(sessions.size())) return nullptr;
  std::lock_guard<std::mutex> lock(fakeMutex);
  if (rejectHistoryLookup && id == secondRecordId) {
    historyLookupCrossedBarrier = true;
    fakeCondition.notify_all();
  }
  auto &session = sessions[static_cast<std::size_t>(id)];
  return session.created && session.visible ? &session : nullptr;
}

std::int64_t fakeSessionId(void *handle) {
  return sessionFor(handle).id;
}

int fakeGetState(void *handle) {
  auto &session = sessionFor(handle);
  std::unique_lock<std::mutex> lock(fakeMutex);
  if (session.id == blockedStateId && !stateReadEntered) {
    stateReadEntered = true;
    fakeCondition.notify_all();
    fakeCondition.wait(lock, [] { return allowStateRead; });
  }
  if (session.id == secondRecordId) {
    secondRecordReached = true;
    fakeCondition.notify_all();
  }
  return session.state;
}

std::int64_t fakeGetI64(void *handle) {
  return sessionFor(handle).id;
}

char *fakeGetString(void *handle) {
  auto &session = sessionFor(handle);
  if (session.id == pauseSerializationId && !serializationEntered) {
    std::unique_lock<std::mutex> lock(fakeMutex);
    serializationEntered = true;
    fakeCondition.notify_all();
    fakeCondition.wait(lock, [] { return allowSerialization; });
  }
  static char empty[] = "";
  return empty;
}

bool fakeGetBool(void *) { return false; }
bool fakeFalse(void *) { return false; }
bool fakeFfmpeg(void *) { return true; }

void *fakeCreateSession(const char *) {
  std::lock_guard<std::mutex> lock(fakeMutex);
  const auto id = nextCreatedId;
  auto &session = sessions[static_cast<std::size_t>(id)];
  session.created = true;
  session.visible = true;
  session.id = id;
  session.state = nextCreatedState;
  return &session;
}

void fakeExecute(void *) {}
std::int64_t fakeHistorySize() { return 0; }

void fakeClearSessions() {
  std::unique_lock<std::mutex> lock(fakeMutex);
  if (blockNativeClear) {
    nativeClearEntered = true;
    fakeCondition.notify_all();
    fakeCondition.wait(lock, [] { return allowNativeClear; });
  }
  if (failNextClear) {
    failNextClear = false;
    throw std::runtime_error("synthetic clear failure");
  }
  clearCalled = true;
  for (auto &session : sessions) {
    if (session.created) session.visible = false;
  }
}

void *resolve(const char *name) {
#define MATCH(symbol, function) \
  if (std::strcmp(name, symbol) == 0) return reinterpret_cast<void *>(&function)
  MATCH("ffmpeg_kit_initialize", fakeInitialize);
  MATCH("ffmpeg_kit_handle_release", fakeRelease);
  MATCH("ffmpeg_kit_free", fakeFree);
  MATCH("ffmpeg_kit_get_session", fakeGetSession);
  MATCH("ffmpeg_kit_create_session", fakeCreateSession);
  MATCH("ffmpeg_kit_session_get_session_id", fakeSessionId);
  MATCH("ffmpeg_kit_session_get_state", fakeGetState);
  MATCH("ffmpeg_kit_session_get_return_code", fakeGetI64);
  MATCH("ffmpeg_kit_session_get_create_time", fakeGetI64);
  MATCH("ffmpeg_kit_session_get_start_time", fakeGetI64);
  MATCH("ffmpeg_kit_session_get_end_time", fakeGetI64);
  MATCH("ffmpeg_kit_session_get_duration", fakeGetI64);
  MATCH("ffmpeg_kit_session_get_logs_count", fakeGetI64);
  MATCH("ffmpeg_kit_session_get_statistics_count", fakeGetI64);
  MATCH("ffmpeg_kit_session_get_command", fakeGetString);
  MATCH("ffmpeg_kit_session_get_output", fakeGetString);
  MATCH("ffmpeg_kit_session_get_logs_as_string", fakeGetString);
  MATCH("ffmpeg_kit_session_get_fail_stack_trace", fakeGetString);
  MATCH("session_is_debug_log_enabled", fakeGetBool);
  MATCH("ffmpeg_kit_session_execute_async", fakeExecute);
  MATCH("ffmpeg_kit_get_session_history_size", fakeHistorySize);
  MATCH("session_is_media_information_session", fakeFalse);
  MATCH("session_is_ffmpeg_session", fakeFfmpeg);
  MATCH("session_is_ffprobe_session", fakeFalse);
  MATCH("session_is_ffplay_session", fakeFalse);
  MATCH("ffmpeg_kit_config_clear_sessions", fakeClearSessions);
#undef MATCH
  return nullptr;
}

void require(bool condition, const char *message) {
  if (!condition) throw std::runtime_error(message);
}

void waitForFlag(bool &value, const char *message) {
  std::unique_lock<std::mutex> lock(fakeMutex);
  require(
      fakeCondition.wait_for(
          lock, std::chrono::seconds(5), [&] { return value; }),
      message);
}

void waitForClearAdmission() {
  for (int attempt = 0; attempt < 5000; ++attempt) {
    if (ffmpegkit::bridge::testing::isSessionClearInProgress()) return;
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }
  throw std::runtime_error("clear admission did not become visible");
}

void resetPhases() {
  std::lock_guard<std::mutex> lock(fakeMutex);
  pauseSerializationId = 0;
  blockedStateId = 0;
  secondRecordId = 0;
  allowSerialization = false;
  allowStateRead = false;
  serializationEntered = false;
  stateReadEntered = false;
  secondRecordReached = false;
  historyFinished = false;
  clearCalled = false;
  blockNativeClear = false;
  nativeClearEntered = false;
  allowNativeClear = false;
  failNextClear = false;
  rejectHistoryLookup = false;
  historyLookupCrossedBarrier = false;
  historyError = nullptr;
  clearError = nullptr;
}

double createHistorySession(std::int64_t id, int state) {
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    nextCreatedId = id;
    nextCreatedState = state;
  }
  return ffmpegkit::bridge::createFFmpegSession("history");
}

void throwThreadError(const std::exception_ptr &error, const char *message) {
  if (error != nullptr) {
    try {
      std::rethrow_exception(error);
    } catch (...) {
      throw std::runtime_error(message);
    }
  }
}

void joinHistory(std::thread &history) {
  history.join();
  throwThreadError(historyError, "history projection failed");
}

void joinClear(std::thread &clear) {
  clear.join();
  throwThreadError(clearError, "clear operation failed unexpectedly");
}

} // namespace

int main() {
  using namespace ffmpegkit::bridge;
  testing::setDynamicSymbolResolver(resolve);
  initialize();

  // A full history projection continues after clear becomes exclusive.
  resetPhases();
  createHistorySession(9, 2);
  createHistorySession(10, 2);
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    pauseSerializationId = 9;
    secondRecordId = 10;
  }
  std::string fullHistory;
  std::thread history([&] {
    try {
      fullHistory = getSessionsJson("all");
    } catch (...) {
      historyError = std::current_exception();
    }
    std::lock_guard<std::mutex> lock(fakeMutex);
    historyFinished = true;
    fakeCondition.notify_all();
  });
  waitForFlag(serializationEntered, "full history did not reach its first record");
  std::thread clear([&] {
    try {
      clearSessions();
    } catch (...) {
      clearError = std::current_exception();
    }
  });
  waitForClearAdmission();
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    allowSerialization = true;
  }
  fakeCondition.notify_all();
  waitForFlag(secondRecordReached, "history did not reach its second record");
  joinHistory(history);
  joinClear(clear);
  require(fullHistory.find("\"sessionId\":9") != std::string::npos,
          "full history omitted the first record");
  require(fullHistory.find("\"sessionId\":10") != std::string::npos,
          "full history omitted the second record");
  require(clearCalled, "clear did not commit after full history");

  // The last-session projection also completes while clear drains the admitted call.
  resetPhases();
  createHistorySession(11, 2);
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    pauseSerializationId = 11;
  }
  std::string lastHistory;
  std::thread last([&] {
    try {
      lastHistory = getLastSessionJson("all");
    } catch (...) {
      historyError = std::current_exception();
    }
    std::lock_guard<std::mutex> lock(fakeMutex);
    historyFinished = true;
    fakeCondition.notify_all();
  });
  waitForFlag(serializationEntered, "last history did not reach serialization");
  std::thread lastClear([&] {
    try {
      clearSessions();
    } catch (...) {
      clearError = std::current_exception();
    }
  });
  waitForClearAdmission();
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    allowSerialization = true;
  }
  fakeCondition.notify_all();
  joinHistory(last);
  joinClear(lastClear);
  require(!lastHistory.empty(), "last history projection returned no record");

  // Running promotion never waits for clear after its state read is admitted.
  resetPhases();
  createHistorySession(12, 1);
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    blockedStateId = 12;
  }
  std::thread runningHistory([&] {
    try {
      (void)getSessionsJson("all");
    } catch (...) {
      historyError = std::current_exception();
    }
    std::lock_guard<std::mutex> lock(fakeMutex);
    historyFinished = true;
    fakeCondition.notify_all();
  });
  waitForFlag(stateReadEntered, "running history did not reach state lookup");
  std::thread runningClear([&] {
    try {
      clearSessions();
    } catch (...) {
      clearError = std::current_exception();
    }
  });
  waitForClearAdmission();
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    allowStateRead = true;
  }
  fakeCondition.notify_all();
  waitForFlag(historyFinished, "running history promotion did not complete");
  joinHistory(runningHistory);
  joinClear(runningClear);

  // Retained and temporary records share one admitted projection transaction.
  resetPhases();
  createHistorySession(13, 1);
  executeSessionAsync(13, 0);
  createHistorySession(14, 2);
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    pauseSerializationId = 13;
  }
  std::string mixedHistory;
  std::thread mixed([&] {
    try {
      mixedHistory = getSessionsJson("all");
    } catch (...) {
      historyError = std::current_exception();
    }
    std::lock_guard<std::mutex> lock(fakeMutex);
    historyFinished = true;
    fakeCondition.notify_all();
  });
  waitForFlag(serializationEntered, "mixed history did not reach retained record");
  std::thread mixedClear([&] {
    try {
      clearSessions();
    } catch (...) {
      clearError = std::current_exception();
    }
  });
  waitForClearAdmission();
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    allowSerialization = true;
  }
  fakeCondition.notify_all();
  waitForFlag(historyFinished, "mixed history did not complete");
  joinHistory(mixed);
  joinClear(mixedClear);
  require(mixedHistory.find("\"sessionId\":13") != std::string::npos,
          "mixed history omitted retained record");
  require(mixedHistory.find("\"sessionId\":14") != std::string::npos,
          "mixed history omitted temporary record");

  // New history calls remain blocked when clear is already exclusive.
  resetPhases();
  createHistorySession(15, 2);
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    blockNativeClear = true;
    secondRecordId = 15;
  }
  std::thread exclusiveClear([&] {
    try {
      clearSessions();
    } catch (...) {
      clearError = std::current_exception();
    }
  });
  waitForFlag(nativeClearEntered, "exclusive clear did not reach native clear");
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    rejectHistoryLookup = true;
  }
  std::thread blockedHistory([&] {
    try {
      (void)getSessionsJson("all");
    } catch (...) {
      historyError = std::current_exception();
    }
    std::lock_guard<std::mutex> lock(fakeMutex);
    historyFinished = true;
    fakeCondition.notify_all();
  });
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    allowNativeClear = true;
    blockNativeClear = false;
  }
  fakeCondition.notify_all();
  joinClear(exclusiveClear);
  joinHistory(blockedHistory);
  require(!historyLookupCrossedBarrier,
          "new history lookup crossed an exclusive clear");

  // A failed clear reopens admission for a history waiter without leaking state.
  resetPhases();
  createHistorySession(16, 2);
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    blockNativeClear = true;
    failNextClear = true;
  }
  std::thread failedClear([&] {
    try {
      clearSessions();
    } catch (...) {
      clearError = std::current_exception();
    }
  });
  waitForFlag(nativeClearEntered, "failing clear did not reach native clear");
  std::string waitingHistory;
  std::thread waiting([&] {
    try {
      waitingHistory = getSessionsJson("all");
    } catch (...) {
      historyError = std::current_exception();
    }
    std::lock_guard<std::mutex> lock(fakeMutex);
    historyFinished = true;
    fakeCondition.notify_all();
  });
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    allowNativeClear = true;
    blockNativeClear = false;
  }
  fakeCondition.notify_all();
  failedClear.join();
  require(clearError != nullptr, "synthetic clear failure was hidden");
  clearError = nullptr;
  joinHistory(waiting);
  require(!waitingHistory.empty(), "history waiter did not resume after clear failure");
  clearSessions();

  testing::resetDynamicSymbolResolver();
  return 0;
}
