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
  assert.deepEqual(parseArguments("ffmpeg '' tail"), ['ffmpeg', '', 'tail']);
});

test('parseArguments preserves Windows and UNC path backslashes', () => {
  assert.deepEqual(
    parseArguments('-i "C:\\Program Files\\Media\\clip.mp4"'),
    ['-i', 'C:\\Program Files\\Media\\clip.mp4'],
  );
  assert.deepEqual(
    parseArguments('\\\\server\\share\\clip.mp4'),
    ['\\\\server\\share\\clip.mp4'],
  );
});

test('argumentsToString leaves simple arguments and backslashes unquoted', () => {
  assert.equal(argumentsToString(['-i', 'input.mp4', 'c\\d']), '-i input.mp4 c\\d');
});

test('argumentsToString safely quotes special values', () => {
  assert.equal(
    argumentsToString(['input file.mp4', 'a"b', "single'value", '']),
    `'input file.mp4' 'a"b' 'single'\\''value' ''`,
  );
});

test('argumentsToString round-trips Windows paths, quotes, and empty values', () => {
  const values = [
    '-filter_complex',
    '[0:v]scale=1280:720[out v]',
    'quote"value',
    "single'value",
    'slash\\value',
    'C:\\Program Files\\Media\\clip.mp4',
    'C:\\Program Files\\Media\\',
    'quote"and\\',
    '\\\\server\\share\\folder with spaces\\',
    '',
  ];

  assert.deepEqual(parseArguments(argumentsToString(values)), values);
});
