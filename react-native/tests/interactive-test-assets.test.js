"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { test } = require("node:test");

const assetsRoot = path.join(__dirname, "..", "example", ".maestro");
const appiumRoot = path.join(__dirname, "..", "example", "interactive-tests", "appium");
const windowsInteractiveRoot = path.join(__dirname, "..", "example", "interactive-tests", "windows");
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
    const appIdMatch = sharedContent.match(/^appId:\s*(.*)$/m);
    assert.equal(appIdMatch?.[1], '${APP_ID}', `${sharedName} must use the platform-neutral app ID parameter`);
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

test("Apple Appium capability examples preserve the local semantic contract", () => {
  const macos = JSON.parse(read(path.join(appiumRoot, "capabilities.macos.example.json")));
  const tvos = JSON.parse(read(path.join(appiumRoot, "capabilities.tvos.example.json")));
  assert.equal(macos.platformName, "mac");
  assert.equal(macos["appium:automationName"], "mac2");
  assert.equal(macos["appium:bundleId"], "org.reactjs.native.FFmpegKitExtendedExample");
  assert.equal(tvos.platformName, "tvOS");
  assert.equal(tvos["appium:automationName"], "XCUITest");
  assert.equal(tvos["appium:bundleId"], "org.reactjs.native.example.FFmpegKitExtendedExample");
  const capabilityContent = `${JSON.stringify(macos)}\n${JSON.stringify(tvos)}`;
  assert.doesNotMatch(capabilityContent, /https?:\/\/(?!127\.0\.0\.1|localhost)/i);
  assert.doesNotMatch(capabilityContent, /(?:udid|deviceudid|password|token|access[_-]?key)\s*[:=]/i);
});

test("Windows AutoGenesis assets preserve a semantic, local-only launch contract", () => {
  const config = JSON.parse(read(path.join(windowsInteractiveRoot, "autogenesis-config.example.json")));
  assert.equal(config.appName, "FFmpegKitExtendedExample");
  assert.match(config.executablePath, /find-windows-example\.ps1/);
  assert.equal(config.testedAutoGenesisCommit, null);
  assert.doesNotMatch(JSON.stringify(config), /^[A-Z]:\\/i);
  const content = read(path.join(windowsInteractiveRoot, "README.md"));
  assert.match(content, /AutomationId|accessibility property/i);
  assert.match(content, /find-windows-example\.ps1/);
  assert.doesNotMatch(content, /maestro cloud/i);
});

