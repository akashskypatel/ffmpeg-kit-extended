'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  ChapterInformation,
  MediaInformation,
  StreamInformation,
} = require('../.test-dist/media-information.js');

test('MediaInformation maps streams, chapters, tags, and properties', () => {
  const media = new MediaInformation({
    filename: 'sample.mp4',
    format: 'mov,mp4,m4a,3gp,3g2,mj2',
    tagsJson: '{"title":"Sample"}',
    allPropertiesJson: '{"probe_score":100}',
    streams: [
      {
        index: 0,
        type: 'video',
        width: 1920,
        height: 1080,
        tagsJson: '{"language":"eng"}',
      },
    ],
    chapters: [
      {
        id: 1,
        start: 0,
        end: 1000,
        tagsJson: '{"title":"Intro"}',
      },
    ],
  });

  assert.equal(media.filename, 'sample.mp4');
  assert.deepEqual(media.tags, {title: 'Sample'});
  assert.deepEqual(media.allProperties, {probe_score: 100});
  assert.equal(media.streams.length, 1);
  assert.ok(media.streams[0] instanceof StreamInformation);
  assert.deepEqual(media.streams[0].tags, {language: 'eng'});
  assert.equal(media.chapters.length, 1);
  assert.ok(media.chapters[0] instanceof ChapterInformation);
  assert.deepEqual(media.chapters[0].tags, {title: 'Intro'});
});

test('MediaInformation defaults missing stream and chapter arrays', () => {
  const media = new MediaInformation({});

  assert.deepEqual(media.streams, []);
  assert.deepEqual(media.chapters, []);
});

test('property JSON getters return undefined for malformed or non-object JSON', () => {
  const stream = new StreamInformation({tagsJson: '["not", "an", "object"]'});
  const chapter = new ChapterInformation({tagsJson: '{invalid'});
  const media = new MediaInformation({allPropertiesJson: 'null'});

  assert.equal(stream.tags, undefined);
  assert.equal(chapter.tags, undefined);
  assert.equal(media.allProperties, undefined);
});
