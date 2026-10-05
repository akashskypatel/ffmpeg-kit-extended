'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  ensureLogMessageLineFeed,
  formatLogOutputIfMissingLineFeeds,
} = require('../.test-dist/log-format.js');

test('adds one line feed to a message without a terminator', () => {
  const log = { sessionId: 1, level: 32, message: 'message' };

  assert.deepEqual(ensureLogMessageLineFeed(log), {
    sessionId: 1,
    level: 32,
    message: 'message\n',
  });
  assert.equal(log.message, 'message');
});

test('preserves existing LF and CRLF endings without duplication', () => {
  const lf = { sessionId: 1, level: 32, message: 'message\n' };
  const crlf = { sessionId: 1, level: 32, message: 'message\r\n' };

  assert.equal(ensureLogMessageLineFeed(lf), lf);
  assert.equal(ensureLogMessageLineFeed(crlf), crlf);
});

test('terminates bare carriage-return and leaves empty messages unchanged', () => {
  assert.equal(
    ensureLogMessageLineFeed({ sessionId: 1, level: 32, message: 'progress\r' })
      .message,
    'progress\r\n'
  );
  const empty = { sessionId: 1, level: 32, message: '' };
  assert.equal(ensureLogMessageLineFeed(empty), empty);
});

test('repairs combined output only when it is raw log concatenation', () => {
  const logs = [
    { sessionId: 1, level: 32, message: 'first' },
    { sessionId: 1, level: 32, message: 'second' },
  ];
  assert.equal(
    formatLogOutputIfMissingLineFeeds('firstsecond', logs),
    'first\nsecond\n'
  );
  assert.equal(
    formatLogOutputIfMissingLineFeeds('first\nsecond\n', [
      { sessionId: 1, level: 32, message: 'first\n' },
      { sessionId: 1, level: 32, message: 'second\n' },
    ]),
    'first\nsecond\n'
  );
  assert.equal(
    formatLogOutputIfMissingLineFeeds('other native formatting', logs),
    'other native formatting'
  );
});
