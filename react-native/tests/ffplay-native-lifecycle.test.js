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

test('React Native Apple owner replacement deactivates the previous view locally', () => {
  for (const source of appleSources) {
    assert.match(
      source,
      /- \(void\)stopAcceptingFrames \{[\s\S]*?_acceptFrames = NO;[\s\S]*?\}/,
    );
    assert.match(
      source,
      /RCTFFplayView \*previousView = coordinator\.view;\s+if \(previousView && previousView != self\) \{\s+\[previousView stopAcceptingFrames\];\s+\}/,
    );
    assert.match(
      source,
      /if \(coordinator\.view != self\) \{\s+\[self stopAcceptingFrames\];\s+return;/,
    );
  }
});
