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

test("holds a transcode input from before duration probing through terminal settlement", async () => {
  const path = "/tmp/input-a.mp4";
  let selectedPath = path;
  let fileExists = true;
  const reservations = new Map();
  const cleanupAttempts = [];
  const retainPath = (reservedPath) => {
    reservations.set(reservedPath, (reservations.get(reservedPath) ?? 0) + 1);
  };
  const releasePath = (reservedPath) => {
    const count = reservations.get(reservedPath) ?? 0;
    if (count <= 1) reservations.delete(reservedPath);
    else reservations.set(reservedPath, count - 1);
  };
  const cleanupPath = (candidate) => {
    cleanupAttempts.push(candidate);
    if (!helpers.shouldRetainImportedPath(candidate, {
      selectedPath,
      hasMediaInfoRead: reservations.has(candidate),
      hasActiveJobs: false,
    })) fileExists = false;
  };

  let finishProbe;
  const probe = new Promise((resolve) => { finishProbe = resolve; });
  const transcode = helpers.withImportedPathReservation(
    path,
    {retainPath, releasePath, cleanupPath},
    async () => probe,
  );
  selectedPath = "/tmp/input-b.mp4";
  cleanupPath(path);
  assert.equal(fileExists, true, "A must remain available while its probe/transcode reservation is held");
  assert.equal(reservations.get(path), 1);

  finishProbe("terminal");
  assert.equal(await transcode, "terminal");
  assert.equal(reservations.has(path), false);
  assert.equal(fileExists, false, "A is reclaimed after the terminal operation releases its reservation");
  assert.equal(cleanupAttempts.at(-1), path);
});

test("releases and cleans a reserved transcode input after startup failure or cancellation", async () => {
  const path = "/tmp/input-a.mp4";
  let selectedPath = "/tmp/input-b.mp4";
  let fileExists = true;
  const reservations = new Map();
  const cleanup = (candidate) => {
    if (!helpers.shouldRetainImportedPath(candidate, {
      selectedPath,
      hasMediaInfoRead: reservations.has(candidate),
      hasActiveJobs: false,
    })) fileExists = false;
  };
  const retainPath = (candidate) => reservations.set(candidate, (reservations.get(candidate) ?? 0) + 1);
  const releasePath = (candidate) => reservations.delete(candidate);
  await assert.rejects(
    helpers.withImportedPathReservation(
      path,
      {retainPath, releasePath, cleanupPath: cleanup},
      async () => { throw new Error("cancelled"); },
    ),
    /cancelled/,
  );
  assert.equal(reservations.has(path), false);
  assert.equal(fileExists, false);
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
