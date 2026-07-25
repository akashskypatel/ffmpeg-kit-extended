'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  argumentsToString,
  parseArguments,
} = require('../.test-dist/arguments.js');

test('parseArguments parses whitespace and quoted arguments', () => {
  assert.deepEqual(
    parseArguments('-i "input file.mp4" -metadata title=\'My Video\' output.mp4'),
    ['-i', 'input file.mp4', '-metadata', 'title=My Video', 'output.mp4'],
  );
});

test('parseArguments handles escaped whitespace and quotes', () => {
  assert.deepEqual(parseArguments('one\\ two "three\\\"four" five'), [
    'one two',
    'three"four',
    'five',
  ]);
});

test('parseArguments preserves empty quoted arguments', () => {
  assert.deepEqual(parseArguments('ffmpeg "" tail'), ['ffmpeg', '', 'tail']);
});

test('parseArguments preserves a trailing escape character', () => {
  assert.deepEqual(parseArguments('value\\'), ['value\\']);
});

test('argumentsToString leaves simple arguments unquoted', () => {
  assert.equal(argumentsToString(['-i', 'input.mp4']), '-i input.mp4');
});

test('argumentsToString quotes and escapes special characters', () => {
  assert.equal(
    argumentsToString(['input file.mp4', 'a"b', 'c\\d', '']),
    '"input file.mp4" "a\\\"b" "c\\\\d" ""',
  );
});

test('argumentsToString round-trips supported argument forms', () => {
  const values = [
    '-filter_complex',
    '[0:v]scale=1280:720[out v]',
    'quote"value',
    'slash\\value',
    '',
  ];

  assert.deepEqual(parseArguments(argumentsToString(values)), values);
});
