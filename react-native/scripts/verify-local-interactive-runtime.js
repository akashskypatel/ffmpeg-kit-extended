"use strict";

const fs = require("node:fs");
const path = require("node:path");
const {
  BINARY_VERSION,
  resolveConfig,
} = require("./resolve-ffmpeg-kit-config.js");

const INTERACTIVE_PLATFORMS = new Set([
  "android",
  "ios",
  "appletvos",
  "macos",
  "windows",
]);

function fail(message) {
  throw new Error(`FFmpegKit [Interactive runtime]: ${message}`);
}

function verifyLocalInteractiveRuntime({ appRoot, platform }) {
  const targetPlatform = String(platform || "").toLowerCase();
  if (!INTERACTIVE_PLATFORMS.has(targetPlatform)) {
    fail(
      `Unsupported interactive platform "${platform}". Expected one of: ${[
        ...INTERACTIVE_PLATFORMS,
      ].join(", ")}.`
    );
  }

  const resolution = resolveConfig({
    appRoot,
    platform: targetPlatform,
    localOnly: true,
  });
  const override = resolution.override;
  if (!override || override.kind !== "local") {
    fail(
      `${targetPlatform} must resolve to an explicit local filesystem override; ` +
        `the frozen FFmpegKit runtime is ${BINARY_VERSION}.`
    );
  }

  const resolvedPath = path.resolve(override.resolvedPath);
  let stats;
  try {
    stats = fs.statSync(resolvedPath);
  } catch (error) {
    if (error && error.code === "ENOENT") {
      fail(`Local ${targetPlatform} runtime does not exist: ${resolvedPath}`);
    }
    fail(`Unable to inspect local ${targetPlatform} runtime ${resolvedPath}: ${error.message}`);
  }

  if (!stats.isFile() && !stats.isDirectory()) {
    fail(`Local ${targetPlatform} runtime must be a file or directory: ${resolvedPath}`);
  }

  return {
    platform: targetPlatform,
    version: resolution.version,
    kind: stats.isDirectory() ? "directory" : "file",
    path: resolvedPath,
    configPath: resolution.configPath,
  };
}

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (!key.startsWith("--")) fail(`Unknown argument: ${key}`);
    const value = argv[index + 1];
    if (value === undefined || value.startsWith("--")) {
      fail(`Missing value for ${key}`);
    }
    args[key.slice(2)] = value;
    index += 1;
  }
  if (!args.platform) fail("--platform is required.");
  return args;
}

if (require.main === module) {
  try {
    const args = parseArgs(process.argv.slice(2));
    const result = verifyLocalInteractiveRuntime({
      appRoot: args["app-root"] || process.cwd(),
      platform: args.platform,
    });
    process.stdout.write(`${JSON.stringify(result)}\n`);
  } catch (error) {
    process.stderr.write(`${error.message || String(error)}\n`);
    process.exitCode = 1;
  }
}

module.exports = {
  INTERACTIVE_PLATFORMS,
  verifyLocalInteractiveRuntime,
};
