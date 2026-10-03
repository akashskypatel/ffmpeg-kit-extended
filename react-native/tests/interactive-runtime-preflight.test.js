"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { afterEach, test } = require("node:test");

const {
  verifyLocalInteractiveRuntime,
} = require("../scripts/verify-local-interactive-runtime.js");

const tempRoots = [];

function createApp(config) {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), "ffmpeg-kit-interactive-"));
  tempRoots.push(root);
  fs.writeFileSync(
    path.join(root, "ffmpeg-kit-extended.config.json"),
    JSON.stringify(config)
  );
  return root;
}

afterEach(() => {
  for (const root of tempRoots.splice(0)) {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test("accepts an existing local file without copying or mutating it", () => {
  const appRoot = fs.mkdtempSync(path.join(os.tmpdir(), "ffmpeg-kit-interactive-"));
  tempRoots.push(appRoot);
  const runtime = path.join(appRoot, "bundle.zip");
  fs.writeFileSync(runtime, "local runtime");
  fs.writeFileSync(
    path.join(appRoot, "ffmpeg-kit-extended.config.json"),
    JSON.stringify({ android: "./bundle.zip" })
  );
  const before = fs.statSync(runtime).size;

  const result = verifyLocalInteractiveRuntime({
    appRoot,
    platform: "android",
  });

  assert.equal(result.kind, "file");
  assert.equal(result.path, runtime);
  assert.equal(result.version, "0.11.2");
  assert.equal(fs.statSync(runtime).size, before);
});

test("accepts an existing local directory", () => {
  const appRoot = fs.mkdtempSync(path.join(os.tmpdir(), "ffmpeg-kit-interactive-"));
  tempRoots.push(appRoot);
  const runtime = path.join(appRoot, "xcframework");
  fs.mkdirSync(runtime);
  fs.writeFileSync(
    path.join(appRoot, "ffmpeg-kit-extended.config.json"),
    JSON.stringify({ ios: "./xcframework" })
  );

  const result = verifyLocalInteractiveRuntime({ appRoot, platform: "ios" });

  assert.equal(result.kind, "directory");
  assert.equal(result.path, runtime);
});

test("rejects a missing local file", () => {
  const appRoot = createApp({ windows: "./missing.zip" });

  assert.throws(
    () => verifyLocalInteractiveRuntime({ appRoot, platform: "windows" }),
    /Local windows runtime does not exist/
  );
});

test("rejects HTTP and HTTPS overrides before any network operation", () => {
  for (const value of [
    "http://example.test/bundle.zip",
    "https://example.test/bundle.zip",
  ]) {
    const appRoot = createApp({ macos: value });
    assert.throws(
      () => verifyLocalInteractiveRuntime({ appRoot, platform: "macos" }),
      /rejects remote bundle overrides/
    );
  }
});

test("rejects an absent override", () => {
  const appRoot = createApp({ type: "base", unrelated: "value" });

  assert.throws(
    () => verifyLocalInteractiveRuntime({ appRoot, platform: "appletvos" }),
    /requires an explicit local bundle override/
  );
});

test("rejects an unrelated configuration without reading a default artifact", () => {
  const appRoot = createApp({ type: "audio", gpl: false, small: true });

  assert.throws(
    () => verifyLocalInteractiveRuntime({ appRoot, platform: "android" }),
    /requires an explicit local bundle override/
  );
});
