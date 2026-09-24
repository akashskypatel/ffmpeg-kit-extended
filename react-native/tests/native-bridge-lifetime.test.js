const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const cppBridge = fs.readFileSync('cpp/FFmpegKitExtendedImpl.cpp', 'utf8');
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
  assert.doesNotMatch(install, /retiredLogBridgeStates\.push_back/);
  assert.doesNotMatch(install, /std::move\(activeLogBridge_\)/);

  assert.match(uninstall, /const auto state = activeLogBridge_/);
  assert.match(uninstall, /deactivateLogBridge\(state\)/);
  assert.doesNotMatch(uninstall, /retiredLogBridgeStates\.push_back/);
  assert.doesNotMatch(uninstall, /std::move\(activeLogBridge_\)/);

  const destructor = section(
    cppBridge,
    'FFmpegKitExtendedImpl::~FFmpegKitExtendedImpl()',
    'void FFmpegKitExtendedImpl::initialize',
  );
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
  assert.doesNotMatch(install, /retainLogBridgeState/);
  assert.doesNotMatch(install, /std::move\(activeLogBridge_\)/);

  assert.match(uninstall, /const auto state = activeLogBridge_/);
  assert.doesNotMatch(uninstall, /retainLogBridgeState/);
  assert.doesNotMatch(uninstall, /std::move\(activeLogBridge_\)/);

  const destructor = section(
    windowsBridge,
    'FFmpegKitExtended::~FFmpegKitExtended()',
    'void FFmpegKitExtended::initialize',
  );
  assert.match(destructor, /retainLogBridgeState\(std::move\(state\)\)/);
});
