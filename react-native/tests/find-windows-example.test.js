"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const {spawnSync} = require("node:child_process");
const {test} = require("node:test");

const helper = path.join(__dirname, "..", "scripts", "find-windows-example.ps1");

function runHelper(exampleRoot, candidatePath) {
  const args = ["-NoProfile", "-ExecutionPolicy", "Bypass", "-File", helper, "-ExampleRoot", exampleRoot];
  if (candidatePath) {
    args.push("-CandidatePath", candidatePath);
  }
  return spawnSync("powershell.exe", args, {
    encoding: "utf8",
    env: {...process.env, FFMPEG_KIT_TASK_TAG: "review-interactive-helper-test"},
  });
}

test("Windows executable discovery selects one project-owned executable", {skip: process.platform !== "win32"}, () => {
  const fixture = fs.mkdtempSync(path.join(os.tmpdir(), "ffmpeg-kit-windows-helper-"));
  try {
    const exampleRoot = path.join(fixture, "windows");
    const first = path.join(exampleRoot, "x64", "Debug", "FFmpegKitExtendedExample.exe");
    fs.mkdirSync(path.dirname(first), {recursive: true});
    fs.writeFileSync(first, "fixture");

    let result = runHelper(exampleRoot);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(path.normalize(result.stdout.trim()), path.normalize(first));

    const second = path.join(exampleRoot, "x64", "Release", "FFmpegKitExtendedExample.exe");
    fs.mkdirSync(path.dirname(second), {recursive: true});
    fs.writeFileSync(second, "fixture");

    result = runHelper(exampleRoot);
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /Multiple FFmpegKitExtendedExample\.exe/);

    result = runHelper(exampleRoot, first);
    assert.equal(result.status, 0, result.stderr);
    assert.equal(path.normalize(result.stdout.trim()), path.normalize(first));
  } finally {
    fs.rmSync(fixture, {recursive: true, force: true});
  }
});

