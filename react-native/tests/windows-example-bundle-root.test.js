"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {test} = require("node:test");

const source = fs.readFileSync(
  path.join(
    __dirname,
    "..",
    "example",
    "windows",
    "FFmpegKitExtendedExample",
    "FFmpegKitExtendedExample.cpp",
  ),
  "utf8",
);

test("packaged Windows example resolves its JS bundle from a filesystem path", () => {
  assert.match(source, /GetCurrentPackagePath\(/);
  assert.match(source, /bundleRootPath\.append\(L"Bundle\\\\"\)/);
  assert.match(source, /settings\.BundleRootPath\(bundleRootPath\.c_str\(\)\)/);
  assert.doesNotMatch(source, /settings\.BundleRootPath\([\s\S]*?L"file:\/\//);
});
