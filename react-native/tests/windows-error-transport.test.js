const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const windowsSource = fs.readFileSync(
  path.join(__dirname, '..', 'windows', 'FFmpegKitExtended', 'FFmpegKitExtended.cpp'),
  'utf8',
);

test('Windows operational dispatch does not use blanket process termination', () => {
  assert.doesNotMatch(windowsSource, /RaiseFailFastException/);
  assert.doesNotMatch(windowsSource, /std::terminate\s*\(/);
  assert.match(windowsSource, /recordOperationalError\(method, error\.what\(\)\)/);
  assert.match(windowsSource, /return Result\{\};/);
});
