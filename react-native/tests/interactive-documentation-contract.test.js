"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {test} = require("node:test");

const root = path.join(__dirname, "..", "..", "docs", "interactive-testing.md");
const rootGuide = fs.readFileSync(root, "utf8");

function read(relativePath) {
  return fs.readFileSync(path.join(__dirname, "..", "..", relativePath), "utf8");
}

test("interactive documentation links every local authority and boundary", () => {
  for (const target of ["Flutter Windows", "Flutter Linux", "Flutter Android", "Flutter macOS", "Flutter iOS", "RN Web", "RN Android", "RN iOS", "RN macOS", "RN tvOS", "RN Windows"]) {
    assert.match(rootGuide, new RegExp(`\\| ${target.replace(" ", " ")} \\|`), target);
  }
  for (const phrase of [
    "local-only",
    "0.11.2",
    "remote or historical ABI",
    "Marionette",
    "Maestro",
    "Appium MCP with Mac2",
    "Appium MCP with XCUITest",
    "AutoGenesis pywinauto MCP",
    "FFMPEG_KIT_TASK_TAG",
    "Expected evidence",
    "Cleanup",
    "Troubleshooting",
  ]) {
    const pattern = phrase === "remote or historical ABI"
      ? /remote or\s+historical ABI/
      : new RegExp(phrase.replace(/[.*+?^${}()|[\\]\\]/g, "\\$&"));
    assert.match(rootGuide, pattern, phrase);
  }
  const flutterGuide = read("flutter/TEST.md");
  const rnGuide = read("react-native/TEST.md");
  const rnExample = read("react-native/example/README.md");
  assert.match(flutterGuide, /Marionette/);
  assert.match(flutterGuide, /local ABI/);
  assert.match(rnGuide, /example\/\.maestro/);
  assert.match(rnGuide, /interactive-tests\/appium/);
  assert.match(rnGuide, /interactive-tests\/windows/);
  assert.match(rnExample, /docs\/interactive-testing\.md/);
  assert.doesNotMatch(rootGuide, /run .*interactive.*(?:GitHub Actions|workflow)/i);
  assert.doesNotMatch(rootGuide, /download .*historical/i);
});

