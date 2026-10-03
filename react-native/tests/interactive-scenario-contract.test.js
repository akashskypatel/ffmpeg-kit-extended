"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {test} = require("node:test");

const contract = fs.readFileSync(
  path.join(__dirname, "..", "..", "docs", "interactive-testing-scenarios.md"),
  "utf8",
);

test("cross-platform interactive scenario contract is explicit and local-only", () => {
  for (const target of ["Flutter", "RN Android", "RN iOS", "RN macOS", "RN Windows", "RN tvOS"]) {
    assert.match(contract, new RegExp(`\\| ${target.replace(" ", " ")} \\|`), target);
  }
  for (const scenario of [
    "Startup/navigation",
    "FFmpeg async version",
    "FFmpeg awaited/sync version",
    "Generate local video",
    "FFprobe generated video",
    "FFplay play/pause/resume/seek/stop",
    "Transcode generated video",
  ]) {
    assert.match(contract, new RegExp(scenario.replace(/[.*+?^${}()|[\\]\\]/g, "\\$&")), scenario);
  }
  for (const category of [
    "build",
    "launch",
    "agent-tool-connectivity",
    "selector/accessibility",
    "wrapper-api",
    "native-runtime",
    "platform-permission",
    "simulator/emulator",
    "test-assumption",
    "external-network",
  ]) {
    assert.match(contract, new RegExp(`^${category.replace("/", "\\/")}$`, "m"), category);
  }
  for (const evidenceField of [
    "frozen implementation source SHA",
    "local runtime path and ABI version",
    "primary failure category when not passed",
    "cleanup result and remaining-process check",
  ]) {
    assert.match(contract, new RegExp(evidenceField), evidenceField);
  }
  assert.match(contract, /local-only/);
  assert.match(contract, /remote or\s+historical ABI/);
  assert.match(contract, /Never claim a scenario passed without execution/);
  assert.match(contract, /Rerun at most once/);
  assert.match(contract, /Do not kill unrelated user processes/);
});

