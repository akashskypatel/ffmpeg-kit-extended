const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const cppBridge = fs.readFileSync('cpp/FFmpegKitExtendedImpl.cpp', 'utf8');
const dynamicApi = fs.readFileSync('cpp/FFmpegKitDynamicApi.cpp', 'utf8');
const nativeLifetimeTest = fs.readFileSync(
  'cpp/retained_handle_lifetime_test.cpp',
  'utf8',
);
const historyComposabilityTest = fs.readFileSync(
  'cpp/history_clear_composability_test.cpp',
  'utf8',
);
const registrationCoordinator = fs.readFileSync(
  'cpp/LogBridgeRegistrationCoordinator.h',
  'utf8',
);
const windowsBridge = fs.readFileSync(
  'windows/FFmpegKitExtended/FFmpegKitExtended.cpp',
  'utf8',
);
const nativeHeader = fs.readFileSync(
  'src/NativeFFmpegKitExtended.ts',
  'utf8',
);
const nativeBackend = fs.readFileSync(
  'src/platform/backend.native.ts',
  'utf8',
);

function section(source, startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  const end = source.indexOf(endMarker, start + startMarker.length);
  assert.notEqual(start, -1, `missing source marker: ${startMarker}`);
  assert.notEqual(end, -1, `missing source marker: ${endMarker}`);
  return source.slice(start, end);
}

test('C++ callback bridge reuses one active state across reinstallations', () => {
  const install = section(
    cppBridge,
    'FFmpegKitExtendedImpl::Completion FFmpegKitExtendedImpl::installLogBridge',
    'FFmpegKitExtendedImpl::Completion FFmpegKitExtendedImpl::uninstallLogBridge',
  );
  const uninstall = section(
    cppBridge,
    'FFmpegKitExtendedImpl::Completion FFmpegKitExtendedImpl::uninstallLogBridge',
    'std::string FFmpegKitExtendedImpl::getSessionJson',
  );

  assert.match(install, /if \(activeLogBridge_ == nullptr\)/);
  assert.match(install, /const auto state = activeLogBridge_/);
  assert.match(install, /logBridgeRegistrationCoordinator\.install/);
  assert.doesNotMatch(install, /retiredLogBridgeStates\.push_back/);
  assert.doesNotMatch(install, /std::move\(activeLogBridge_\)/);

  assert.match(uninstall, /const auto state = activeLogBridge_/);
  assert.match(uninstall, /logBridgeRegistrationCoordinator\.uninstallIfOwned/);
  assert.match(uninstall, /deactivateLogBridge\(state\)/);
  assert.doesNotMatch(uninstall, /retiredLogBridgeStates\.push_back/);
  assert.doesNotMatch(uninstall, /std::move\(activeLogBridge_\)/);

  const destructor = section(
    cppBridge,
    'FFmpegKitExtendedImpl::~FFmpegKitExtendedImpl()',
    'FFmpegKitExtendedImpl::Completion FFmpegKitExtendedImpl::initialize',
  );
  assert.match(destructor, /logBridgeRegistrationCoordinator\.uninstallIfOwned/);
  assert.match(destructor, /retainRetiredLogBridgeState\(state\)/);
});
test('Windows callback bridge reuses one active state and retires only on destruction', () => {
  const install = section(
    windowsBridge,
    'void FFmpegKitExtended::installLogBridge',
    'void FFmpegKitExtended::uninstallLogBridge',
  );
  const uninstall = section(
    windowsBridge,
    'void FFmpegKitExtended::uninstallLogBridge',
    'std::string FFmpegKitExtended::getSessionJson',
  );

  assert.match(install, /if \(!activeLogBridge_\)/);
  assert.match(install, /const auto state = activeLogBridge_/);
  assert.match(install, /logBridgeRegistrationCoordinator\.install/);
  assert.doesNotMatch(install, /retainLogBridgeState/);
  assert.doesNotMatch(install, /std::move\(activeLogBridge_\)/);

  assert.match(uninstall, /const auto state = activeLogBridge_/);
  assert.match(uninstall, /logBridgeRegistrationCoordinator\.uninstallIfOwned/);
  assert.doesNotMatch(uninstall, /retainLogBridgeState/);
  assert.doesNotMatch(uninstall, /std::move\(activeLogBridge_\)/);

  const destructor = section(
    windowsBridge,
    'FFmpegKitExtended::~FFmpegKitExtended()',
    'void FFmpegKitExtended::initialize',
  );
  assert.match(destructor, /logBridgeRegistrationCoordinator\.uninstallIfOwned/);
  assert.match(destructor, /retainLogBridgeState\(std::move\(state\)\)/);
});

test('registration coordinator commits and clears only the current owner', () => {
  assert.match(registrationCoordinator, /class LogBridgeRegistrationCoordinator/);
  assert.match(registrationCoordinator, /currentOwner_ = owner/);
  assert.match(registrationCoordinator, /if \(currentOwner_ != owner\) return false/);
  assert.match(registrationCoordinator, /currentOwner_ = nullptr/);
});

test('native session cleanup clears owning handles through the registry-aware API', () => {
  const start = dynamicApi.indexOf('void clearSessions()');
  const end = dynamicApi.indexOf(
    'std::string registerNewFFmpegPipe()',
    start,
  );
  assert.notEqual(start, -1);
  assert.notEqual(end, -1);
  const clearSessions = dynamicApi.slice(start, end);

  assert.match(
    clearSessions,
    /resolve<Fn>\("ffmpeg_kit_config_clear_sessions"\)\(\)/,
  );
  assert.doesNotMatch(
    clearSessions,
    /resolve<Fn>\("ffmpeg_kit_clear_sessions"\)\(\)/,
  );
  assert.match(clearSessions, /retainedSessionHandles\.clear\(\)/);
  assert.match(clearSessions, /activeSessionOperations == 0/);
  assert.ok(
    clearSessions.indexOf('retainedSessionHandles.clear()') <
      clearSessions.indexOf('historyRecords.clear()'),
  );
  assert.ok(
    clearSessions.indexOf('historyRecords.clear()') <
      clearSessions.lastIndexOf('clearSessionsInProgress = false'),
  );
});

test('native handle cleanup caches lifetime symbols and commits retained release atomically', () => {
  const initialization = section(
    dynamicApi,
    'void ensureInitialized()',
    'void release(Handle handle) noexcept',
  );
  assert.match(initialization, /resolve<HandleReleaseFn>\("ffmpeg_kit_handle_release"\)/);
  assert.match(initialization, /resolve<FreeMemoryFn>\("ffmpeg_kit_free"\)/);
  assert.match(initialization, /runtimeLifetimeApi = lifetimeApi/);

  const guard = section(
    dynamicApi,
    'struct HandleGuard',
    'std::int64_t sessionIdOf',
  );
  assert.match(guard, /RetainedHandleLease/);
  assert.match(guard, /retainedLease/);
  assert.match(guard, /~HandleGuard\(\) noexcept/);
  assert.match(guard, /HandleGuard &operator=\(HandleGuard &&other\) noexcept/);
  assert.doesNotMatch(guard, /resolve</);

  const retainedRelease = section(
    dynamicApi,
    'void releaseRetainedSession',
    'std::string sessionType',
  );
  assert.match(retainedRelease, /entry->releasing/);
  assert.match(retainedRelease, /activeRetainedReleases/);
  assert.match(retainedRelease, /sessionHandlesCondition\.wait/);
  assert.match(retainedRelease, /release\(entry->handle\)/);
  assert.match(retainedRelease, /retainedSessionHandles\.erase\(it\)/);
  assert.ok(
    retainedRelease.indexOf('release(entry->handle)') <
      retainedRelease.indexOf('retainedSessionHandles.erase(it)'),
  );
});

test('native handle acquisition uses one borrow/release/clear lifetime authority', () => {
  assert.match(dynamicApi, /struct RetainedSessionEntry/);
  assert.match(dynamicApi, /activeBorrows/);
  assert.match(dynamicApi, /activeRetainedBorrows/);
  assert.match(dynamicApi, /activeSessionOperations/);
  assert.match(dynamicApi, /clearSessionsInProgress/);
  assert.match(dynamicApi, /Session handle release is already in progress/);
  assert.match(dynamicApi, /HandleGuard\(RetainedHandleLease/);
  assert.match(dynamicApi, /acquireHistorySession/);
  assert.match(dynamicApi, /getFFplaySession/);
  assert.match(dynamicApi, /getMediaInformationJson/);
  assert.match(dynamicApi, /getStatisticsJson/);
  assert.match(dynamicApi, /clearSessions\(\)[\s\S]*activeSessionOperations == 0/);
  assert.match(dynamicApi, /createSessionWith[\s\S]*acquireSessionOperation/);
  assert.match(dynamicApi, /getSessionsJson[\s\S]*acquireSessionOperation/);
  assert.match(dynamicApi, /getLastSessionJson[\s\S]*acquireSessionOperation/);
  assert.match(nativeLifetimeTest, /a new borrow was admitted after release began/);
  assert.match(nativeLifetimeTest, /clear crossed an active borrower/);
  assert.match(nativeLifetimeTest, /duplicate release was admitted/);
});

test('history projection reuses one composable registry operation authority', () => {
  const operationLease = section(
    dynamicApi,
    'struct SessionOperationToken',
    'void releaseRetainedBorrow',
  );
  assert.match(operationLease, /std::shared_ptr<SessionOperationToken>/);
  assert.match(operationLease, /SessionOperationLease\(const SessionOperationLease &\) = default/);

  const nestedAcquisition = section(
    dynamicApi,
    'HandleGuard acquireSessionWithinOperation',
    'HandleGuard acquireSession(std::int64_t id)',
  );
  assert.doesNotMatch(nestedAcquisition, /acquireSessionOperation\(\)/);

  const historyAcquisition = section(
    dynamicApi,
    'HandleGuard acquireHistorySessionWithinOperation',
    'void releaseRetainedSession',
  );
  assert.doesNotMatch(
    historyAcquisition,
    /sessionHandlesCondition\.wait\(lock, \[\] \{ return !clearSessionsInProgress; \}\)/,
  );
  assert.match(historyAcquisition, /acquireSessionWithinOperation/);

  const historyProjection = section(
    dynamicApi,
    'std::string getSessionsJson',
    'std::string getLogsJson',
  );
  assert.match(historyProjection, /auto operation = acquireSessionOperation\(\)/);
  assert.match(historyProjection, /acquireHistorySessionWithinOperation/);
  assert.doesNotMatch(historyProjection, /acquireHistorySession\(record\.sessionId\)/);

  assert.match(historyComposabilityTest, /full history projection/);
  assert.match(historyComposabilityTest, /last-session projection/);
  assert.match(historyComposabilityTest, /Running promotion/);
  assert.match(historyComposabilityTest, /Retained and temporary records/);
  assert.match(historyComposabilityTest, /New history calls remain blocked/);
  assert.match(historyComposabilityTest, /failed clear reopens admission/);
});

test('native session history projects recorded identities without enumerating owning arrays', () => {
  assert.match(dynamicApi, /struct HistoryRecord/);
  assert.match(dynamicApi, /rememberHistorySession/);
  assert.match(dynamicApi, /visibleHistoryRecords\(kind\)/);
  assert.match(dynamicApi, /acquireHistorySession/);
  assert.match(dynamicApi, /markHistorySessionTerminal/);
  assert.match(dynamicApi, /pruneTerminalHistory/);
  assert.match(dynamicApi, /removeNonTerminalHistorySession/);
  assert.match(dynamicApi, /void abandonCreatedSession\(double sessionId\)/);
  assert.match(dynamicApi, /abandonCreatedSession[\s\S]*?removeNonTerminalHistorySession/);
  assert.match(dynamicApi, /kCompletedSessionState/);
  assert.match(dynamicApi, /historyRecords\.clear\(\)/);
  assert.doesNotMatch(dynamicApi, /collectNativeSessionHandles/);
  assert.doesNotMatch(dynamicApi, /sessionHistoryExport\(kind\)/);
  assert.doesNotMatch(dynamicApi, /lastSessionExport\(kind\)/);
  assert.doesNotMatch(
    dynamicApi,
    /knownSessionIds|knownSessionIdSet|pruneKnownSessionIds|sessionIdsSnapshot/,
  );
});

test('native monitor state polling uses the scalar bridge surface', () => {
  assert.match(nativeHeader, /getSessionState\(sessionId: Double\): Int32/);
  assert.match(dynamicApi, /std::int32_t getSessionState\(double sessionId\)/);
  assert.match(
    dynamicApi,
    /getSessionState\(double sessionId\)[\s\S]*?acquireSession\(toId\(sessionId\)\)/,
  );
  assert.match(dynamicApi, /ffmpeg_kit_session_get_state/);
  assert.match(nativeBackend, /invokeSynchronousNative<number>\('getSessionState', \[sessionId\]\)/);
  const scalarStateBranch = section(
    nativeBackend,
    "if (property === 'getSessionState')",
    "if (property === 'isSessionAbandoned')",
  );
  assert.doesNotMatch(scalarStateBranch, /getSessionJson\(/);
  assert.match(windowsBridge, /FFmpegKitExtended::getSessionState/);
});

test('native wrapper history rejects abandoned IDs before direct reconstruction', () => {
  assert.match(nativeBackend, /const abandonedSessionIds = new Set/);
  assert.match(nativeBackend, /property === 'isSessionAbandoned'/);
  assert.match(nativeBackend, /property === 'abandonCreatedSession'/);
  assert.match(nativeBackend, /property === 'getSessionJson'[\s\S]*abandonedSessionIds/);
  assert.match(nativeBackend, /property === 'clearSessions'[\s\S]*abandonedSessionIds\.clear/);
  const clearBranch = section(
    nativeBackend,
    "if (property === 'clearSessions')",
    'const nativeValue = Reflect.get(target, property, receiver);',
  );
  assert.match(
    clearBranch,
    /invokeAsyncNative\('clearSessions', \[\]\)[\s\S]*abandonedSessionIds\.clear/,
  );
  assert.match(nativeBackend, /reconcileAbandonedSessionId/);
  assert.match(
    nativeBackend,
    /invokeSynchronousNative<string>\('getSessionJson', \[candidate\]\)/,
  );
  assert.doesNotMatch(
    nativeBackend,
    /const json = NativeFFmpegKitExtended\.getSessionJson\(sessionId\)/,
  );
  assert.doesNotMatch(nativeBackend, /abandonmentReconciliationThreshold/);
  assert.doesNotMatch(nativeBackend, /abandonmentEventsSinceReconciliation/);
  assert.match(nativeBackend, /recordCancellationIntent/);
  assert.match(nativeBackend, /isCancellationRequested/);
  assert.match(nativeBackend, /clearCancellationIntent/);
});
