const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const cppBridge = fs.readFileSync('cpp/FFmpegKitExtendedImpl.cpp', 'utf8');
const dynamicApi = fs.readFileSync('cpp/FFmpegKitDynamicApi.cpp', 'utf8');
const registrationCoordinator = fs.readFileSync(
  'cpp/LogBridgeRegistrationCoordinator.h',
  'utf8',
);
const windowsBridge = fs.readFileSync(
  'windows/FFmpegKitExtended/FFmpegKitExtended.cpp',
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
    'void FFmpegKitExtendedImpl::installLogBridge',
    'void FFmpegKitExtendedImpl::uninstallLogBridge',
  );
  const uninstall = section(
    cppBridge,
    'void FFmpegKitExtendedImpl::uninstallLogBridge',
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
    'void FFmpegKitExtendedImpl::initialize',
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
  assert.match(clearSessions, /knownSessionIds\.clear\(\)/);
});
