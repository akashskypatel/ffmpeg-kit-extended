const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const packageRoot = path.resolve(__dirname, '..');
const read = relativePath =>
  fs.readFileSync(path.join(packageRoot, relativePath), 'utf8');

test('README describes FFplay monitoring queries and awaited controls', () => {
  const readme = read('README.md');

  assert.match(
    readme,
    /Playback Monitoring.*position and video-dimension queries/s,
  );
  assert.doesNotMatch(readme, /Position and video dimension streams/);
  assert.match(
    readme,
    /await session\.pause\(\);[\s\S]*await session\.seek\(10\);[\s\S]*await session\.resume\(\);[\s\S]*await session\.setVolume\(0\.5\);/,
  );
});

test('FFplay current-session documentation describes newest unsettled ownership', () => {
  const source = read('src/ffplay-kit.ts');

  assert.match(source, /newest submitted high-level FFplay session/);
  assert.match(source, /execution Promise remains unsettled/);
  assert.match(source, /falls back to the next newest unsettled session/);
  assert.doesNotMatch(source, /remains current until this method's Promise settles/);
});
