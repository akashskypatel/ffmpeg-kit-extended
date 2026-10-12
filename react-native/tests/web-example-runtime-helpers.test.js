"use strict";

const assert = require("node:assert/strict");
const path = require("node:path");
const { before, test } = require("node:test");
const { pathToFileURL } = require("node:url");

let helpers;

before(async () => {
  helpers = await import(
    pathToFileURL(path.join(__dirname, "..", "example", "web", "runtime-helpers.mjs"))
      .href
  );
});

test("retains retired imports while any FFmpeg, FFprobe, or FFplay job is active", () => {
  assert.equal(
    helpers.shouldRetainImportedPath("/tmp/input-a.mp4", {
      selectedPath: "/tmp/input-b.mp4",
      hasMediaInfoRead: false,
      hasActiveJobs: true,
    }),
    true,
  );
  assert.equal(
    helpers.shouldRetainImportedPath("/tmp/input-a.mp4", {
      selectedPath: "/tmp/input-b.mp4",
      hasMediaInfoRead: true,
      hasActiveJobs: false,
    }),
    true,
  );
  assert.equal(
    helpers.shouldRetainImportedPath("/tmp/input-a.mp4", {
      selectedPath: "/tmp/input-b.mp4",
      hasMediaInfoRead: false,
      hasActiveJobs: false,
    }),
    false,
  );
});

test("reads only finite positive FFprobe durations in seconds", () => {
  assert.equal(helpers.readDurationSeconds(24), 24);
  assert.equal(helpers.readDurationSeconds("24.5"), 24.5);
  for (const value of [undefined, null, "", "N/A", "Infinity", 0, -1, Number.NaN]) {
    assert.equal(helpers.readDurationSeconds(value), undefined);
  }
});

test("converts millisecond statistics to duration progress and stays monotonic below completion", () => {
  assert.equal(helpers.advanceTranscodeProgressPercent(12_000, 24, 0), 50);
  assert.equal(helpers.advanceTranscodeProgressPercent(8_000, 24, 50), 50);
  assert.equal(helpers.advanceTranscodeProgressPercent(24_000, 24, 50), 99);
  assert.equal(helpers.advanceTranscodeProgressPercent(48_000, 24, 99), 99);
  assert.equal(helpers.advanceTranscodeProgressPercent(4_000, undefined, 0), undefined);
  assert.equal(helpers.advanceTranscodeProgressPercent(Number.NaN, 8, 0), undefined);
});
