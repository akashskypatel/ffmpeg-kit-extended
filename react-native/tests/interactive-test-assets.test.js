"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const assetsRoot = path.join(__dirname, "..", "example", ".maestro");
const rootFlows = {
  android: {
    file: path.join(assetsRoot, "android", "core-media-smoke.yaml"),
    appId: "com.akashskypatel.ffmpegkitextendedexample",
  },
  ios: {
    file: path.join(assetsRoot, "ios", "core-media-smoke.yaml"),
    appId: "org.reactjs.native.example.FFmpegKitExtendedExample",
  },
};
const sharedNames = [
  "ffmpeg-version.yaml",
  "generated-media-probe.yaml",
  "ffplay-control-cycle.yaml",
  "transcode-generated-media.yaml",
];
const semanticSelectors = [
  "app.root",
  "logs.output",
  "tab.ffmpeg",
  "tab.stream",
  "tab.ffprobe",
  "tab.ffplay",
  "tab.transcode",
  "ffmpeg.version.async",
  "ffmpeg.version.awaited",
  "ffmpeg.generate-video",
  "ffprobe.media-info",
  "ffplay.play-video",
  "ffplay.pause",
  "ffplay.resume",
  "ffplay.stop",
  "transcode.run",
];

function read(file) {
  assert.equal(fs.existsSync(file), true, `Missing Maestro asset: ${file}`);
  return fs.readFileSync(file, "utf8");
}

test("Maestro mobile flow assets preserve the local semantic contract", () => {
  const rootContents = Object.values(rootFlows).map(({file, appId}) => {
    const content = read(file);
    assert.match(content, new RegExp(`appId:\\s*${appId.replaceAll(".", "\\.")}`));
    for (const sharedName of sharedNames) {
      assert.match(content, new RegExp(`\\.\\./shared/${sharedName.replaceAll(".", "\\.")}`));
    }
    return content;
  });

  for (const sharedName of sharedNames) {
    const sharedContent = read(path.join(assetsRoot, "shared", sharedName));
    assert.doesNotMatch(sharedContent, /^appId:/m, `${sharedName} must be platform-neutral`);
    for (const selector of semanticSelectors) {
      if (sharedContent.includes(selector)) {
        assert.match(sharedContent, new RegExp(selector.replaceAll(".", "\\.")));
      }
    }
  }

  const allContent = [...rootContents, ...sharedNames.map(name => read(path.join(assetsRoot, "shared", name)))].join("\n");
  for (const selector of semanticSelectors) {
    assert.match(allContent, new RegExp(selector.replaceAll(".", "\\.")), selector);
  }
  assert.doesNotMatch(allContent, /maestro\s+cloud/i);
  assert.doesNotMatch(allContent, /(?:tapOn|swipe|longPress):\s*\{?\s*(?:x|y|point|coordinates)\b/i);
});
