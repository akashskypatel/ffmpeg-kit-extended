#include "FFmpegKitDynamicApi.h"

#include <array>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <cstring>
#include <mutex>
#include <stdexcept>
#include <thread>

namespace {

struct FakeSession {
  bool created = false;
  bool visible = false;
  std::int64_t id = 0;
};

std::array<FakeSession, 16> sessions{};
std::mutex fakeMutex;
std::condition_variable fakeCondition;
bool borrowEntered = false;
bool allowBorrow = false;
bool blockBorrowState = false;
bool borrowBlockConsumed = false;
bool clearCalled = false;
bool failNextClear = false;
bool failNextStateLookup = false;
bool blockNativeRelease = false;
bool nativeReleaseEntered = false;
bool allowNativeRelease = false;
bool blockNativeClear = false;
bool nativeClearEntered = false;
bool allowNativeClear = false;
bool blockSessionCreation = false;
bool sessionCreationEntered = false;
bool allowSessionCreation = false;
std::size_t releaseCount = 0;

FakeSession &sessionFor(void *handle) {
  return *static_cast<FakeSession *>(handle);
}

void fakeInitialize() {}
void fakeFree(void *) {}

void fakeRelease(void *handle) {
  (void)handle;
  std::unique_lock<std::mutex> lock(fakeMutex);
  ++releaseCount;
  if (!blockNativeRelease) return;
  nativeReleaseEntered = true;
  fakeCondition.notify_all();
  fakeCondition.wait(lock, [] { return allowNativeRelease; });
}

std::int64_t fakeSessionId(void *handle) {
  return sessionFor(handle).id;
}

void *fakeGetSession(std::int64_t id) {
  if (id <= 0 || id >= static_cast<std::int64_t>(sessions.size())) return nullptr;
  auto &session = sessions[static_cast<std::size_t>(id)];
  std::lock_guard<std::mutex> lock(fakeMutex);
  if (!session.created) {
    session.created = true;
    session.visible = true;
    session.id = id;
  }
  return session.visible ? &session : nullptr;
}

int fakeGetState(void *handle) {
  auto &session = sessionFor(handle);
  std::unique_lock<std::mutex> lock(fakeMutex);
  if (failNextStateLookup) {
    failNextStateLookup = false;
    throw std::runtime_error("synthetic state lookup failure");
  }
  if (blockBorrowState && !borrowBlockConsumed &&
      (session.id <= 2 || session.id == 6)) {
    borrowEntered = true;
    fakeCondition.notify_all();
    fakeCondition.wait(lock, [] { return allowBorrow; });
    borrowBlockConsumed = true;
  }
  return 2;
}

void *fakeCreateSession(const char *) {
  std::unique_lock<std::mutex> lock(fakeMutex);
  auto &session = sessions[8];
  session.created = true;
  session.visible = true;
  session.id = 8;
  if (blockSessionCreation) {
    sessionCreationEntered = true;
    fakeCondition.notify_all();
    fakeCondition.wait(lock, [] { return allowSessionCreation; });
  }
  return &session;
}

void fakeExecute(void *) {}
std::int64_t fakeHistorySize() { return 0; }
bool fakeFalse(void *) { return false; }
bool fakeFfmpeg(void *) { return true; }

void fakeClearSessions() {
  std::unique_lock<std::mutex> lock(fakeMutex);
  if (failNextClear) {
    failNextClear = false;
    throw std::runtime_error("synthetic clear failure");
  }
  if (blockNativeClear) {
    nativeClearEntered = true;
    fakeCondition.notify_all();
    fakeCondition.wait(lock, [] { return allowNativeClear; });
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

void waitFor(bool &value) {
  std::unique_lock<std::mutex> lock(fakeMutex);
  fakeCondition.wait(lock, [&] { return value; });
}

void waitForReleaseBarrier(std::int64_t sessionId) {
  for (int attempt = 0; attempt < 1000; ++attempt) {
    if (ffmpegkit::bridge::testing::isRetainedSessionReleasing(sessionId)) return;
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }
  throw std::runtime_error("release barrier did not become visible");
}

void waitForClearBarrier() {
  for (int attempt = 0; attempt < 1000; ++attempt) {
    if (ffmpegkit::bridge::testing::isSessionClearInProgress()) return;
    std::this_thread::sleep_for(std::chrono::milliseconds(1));
  }
  throw std::runtime_error("clear barrier did not become visible");
}

void waitForNativeClear() {
  std::unique_lock<std::mutex> lock(fakeMutex);
  fakeCondition.wait(lock, [] { return nativeClearEntered; });
}

void require(bool condition, const char *message) {
  if (!condition) throw std::runtime_error(message);
}

template <typename Function>
void requireThrows(Function &&function, const char *message) {
  bool threw = false;
  try {
    function();
  } catch (const std::exception &) {
    threw = true;
  }
  require(threw, message);
}

} // namespace

int main() {
  using namespace ffmpegkit::bridge;
  testing::setDynamicSymbolResolver(resolve);
  initialize();

  executeSessionAsync(1, 0);
  blockBorrowState = true;
  std::thread borrower([] { require(getSessionState(1) == 2, "borrow failed"); });
  waitFor(borrowEntered);
  std::thread releaser([] { releaseSessionHandle(1); });
  waitForReleaseBarrier(1);
  requireThrows([] { getSessionState(1); },
                "a new borrow was admitted after release began");
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    allowBorrow = true;
  }
  fakeCondition.notify_all();
  borrower.join();
  releaser.join();
  require(releaseCount == 1, "retained handle was not released once");

  executeSessionAsync(2, 0);
  blockBorrowState = true;
  borrowBlockConsumed = false;
  allowBorrow = false;
  borrowEntered = false;
  clearCalled = false;
  std::thread clearBorrower([] { require(getSessionState(2) == 2, "clear borrow failed"); });
  waitFor(borrowEntered);
  std::thread clearer([] { clearSessions(); });
  waitForClearBarrier();
  {
    std::unique_lock<std::mutex> lock(fakeMutex);
    require(!fakeCondition.wait_for(lock, std::chrono::milliseconds(100),
                                    [] { return clearCalled; }),
            "clear crossed an active borrower");
    allowBorrow = true;
  }
  fakeCondition.notify_all();
  clearBorrower.join();
  clearer.join();
  require(clearCalled, "clear did not reach the native clear entrypoint");
  requireThrows([] { getSessionState(2); },
                "cleared retained identity was reconstructed");

  executeSessionAsync(3, 0);
  blockNativeRelease = true;
  allowNativeRelease = false;
  nativeReleaseEntered = false;
  std::thread firstRelease([] { releaseSessionHandle(3); });
  waitFor(nativeReleaseEntered);
  requireThrows([] { releaseSessionHandle(3); },
                "duplicate release was admitted");
  {
    std::lock_guard<std::mutex> lock(fakeMutex);
    allowNativeRelease = true;
    blockNativeRelease = false;
  }
  fakeCondition.notify_all();
  firstRelease.join();

  executeSessionAsync(4, 0);
  failNextStateLookup = true;
  requireThrows([] { releaseSessionHandle(4); },
                "pre-release lookup failure was hidden");
  getSessionState(4);
  releaseSessionHandle(4);

  executeSessionAsync(5, 0);
  failNextClear = true;
  requireThrows([] { clearSessions(); }, "native clear failure was hidden");
  require(getSessionState(5) == 2, "failed clear discarded retained ownership");
  clearSessions();

  blockBorrowState = true;
  borrowBlockConsumed = false;
  allowBorrow = false;
  borrowEntered = false;
  clearCalled = false;
  std::thread temporaryReader([] {
    require(getSessionState(6) == 2, "temporary read failed");
  });
  waitFor(borrowEntered);
  std::thread temporaryClear([] { clearSessions(); });
  waitForClearBarrier();
  {
    std::unique_lock<std::mutex> lock(fakeMutex);
    require(!fakeCondition.wait_for(lock, std::chrono::milliseconds(100),
                                    [] { return clearCalled; }),
            "clear crossed a temporary native read");
    allowBorrow = true;
  }
  fakeCondition.notify_all();
  temporaryReader.join();
  temporaryClear.join();

  blockSessionCreation = true;
  sessionCreationEntered = false;
  allowSessionCreation = false;
  clearCalled = false;
  std::thread creator([] {
    require(createFFmpegSession("synthetic") == 8, "session creation failed");
  });
  waitFor(sessionCreationEntered);
  std::thread creationClear([] { clearSessions(); });
  waitForClearBarrier();
  {
    std::unique_lock<std::mutex> lock(fakeMutex);
    require(!fakeCondition.wait_for(lock, std::chrono::milliseconds(100),
                                    [] { return clearCalled; }),
            "clear crossed an active session creation");
    allowSessionCreation = true;
  }
  fakeCondition.notify_all();
  creator.join();
  creationClear.join();

  blockNativeClear = true;
  nativeClearEntered = false;
  allowNativeClear = false;
  blockSessionCreation = false;
  sessionCreationEntered = false;
  clearCalled = false;
  std::thread exclusiveClear([] { clearSessions(); });
  waitForClearBarrier();
  waitForNativeClear();
  std::thread blockedCreator([] {
    require(createFFmpegSession("after-clear-start") == 8,
            "post-clear session creation failed");
  });
  {
    std::unique_lock<std::mutex> lock(fakeMutex);
    require(!fakeCondition.wait_for(lock, std::chrono::milliseconds(100),
                                    [] { return sessionCreationEntered; }),
            "session creation crossed an exclusive clear");
    allowNativeClear = true;
  }
  fakeCondition.notify_all();
  exclusiveClear.join();
  blockedCreator.join();
  blockNativeClear = false;

  testing::resetDynamicSymbolResolver();
  return 0;
}
