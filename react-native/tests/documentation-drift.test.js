const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const {compareTrees} = require('../scripts/check-api-docs');

function withTrees(callback) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-api-drift-test-'));
  const expected = path.join(root, 'expected');
  const actual = path.join(root, 'actual');
  fs.mkdirSync(expected);
  fs.mkdirSync(actual);
  try {
    return callback(expected, actual);
  } finally {
    fs.rmSync(root, {recursive: true, force: true});
  }
}

test('drift comparison normalizes line endings', () => {
  withTrees((expected, actual) => {
    fs.writeFileSync(path.join(expected, 'README.md'), 'one\ntwo\n');
    fs.writeFileSync(path.join(actual, 'README.md'), 'one\r\ntwo\r\n');
    assert.deepEqual(compareTrees(expected, actual), {
      added: [],
      missing: [],
      changed: [],
    });
  });
});

test('drift comparison reports added, missing, and changed files', () => {
  withTrees((expected, actual) => {
    fs.writeFileSync(path.join(expected, 'same.md'), 'same');
    fs.writeFileSync(path.join(expected, 'missing.md'), 'missing');
    fs.writeFileSync(path.join(expected, 'changed.md'), 'old');
    fs.writeFileSync(path.join(actual, 'same.md'), 'same');
    fs.writeFileSync(path.join(actual, 'added.md'), 'added');
    fs.writeFileSync(path.join(actual, 'changed.md'), 'new');
    assert.deepEqual(compareTrees(expected, actual), {
      added: ['added.md'],
      missing: ['missing.md'],
      changed: ['changed.md'],
    });
  });
});
