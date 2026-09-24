'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const windowsHeader = fs.readFileSync('windows/FFmpegKitExtended/FFplayView.h', 'utf8');
const windowsSource = fs.readFileSync('windows/FFmpegKitExtended/FFplayView.cpp', 'utf8');
const appleSources = [
  fs.readFileSync('ios/RCTFFplayView.mm', 'utf8'),
  fs.readFileSync('appletvos/RCTFFplayView.mm', 'utf8'),
  fs.readFileSync('macos/RCTFFplayView.mm', 'utf8'),
];

test('React Native Windows resolves a complete FFplay callback pair on every retry', () => {
  assert.match(windowsHeader, /static bool ResolveFrameCallbacks\(\) noexcept/);
  assert.match(windowsSource, /if \(!ResolveFrameCallbacks\(\)\)/);
  assert.match(windowsSource, /if \(registerCallback && unregisterCallback\)/);
  assert.match(
    windowsSource,
    /s_registerFrameCallback = nullptr;\s+s_unregisterFrameCallback = nullptr;\s+return false;/s,
  );
  assert.doesNotMatch(windowsSource, /static RegisterFrameCallback callback = \[\]/);
  assert.doesNotMatch(windowsSource, /static UnregisterFrameCallback callback = \[\]/);
});

test('React Native Apple activation requires register and unregister symbols together', () => {
  for (const source of appleSources) {
    assert.match(source, /if \(!gRegisterFrameCallback \|\| !gUnregisterFrameCallback\)/);
    assert.match(
      source,
      /gRegisterFrameCallback = NULL;\s+gUnregisterFrameCallback = NULL;/s,
    );
    assert.doesNotMatch(
      source,
      /if \(!gRegisterFrameCallback\) \{\s+NSLog\(/s,
    );
  }
});
