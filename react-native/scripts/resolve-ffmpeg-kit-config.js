"use strict";

const crypto = require("crypto");
const fs = require("fs");
const path = require("path");

const CONFIG_FILE_NAME = "ffmpeg-kit-extended.config.json";
const BINARY_VERSION = "0.11.2";
const BASE_RELEASE_URL =
  "https://github.com/akashskypatel/ffmpeg-kit-builders/releases/download";
const RELEASE_API_URL =
  "https://api.github.com/repos/akashskypatel/ffmpeg-kit-builders/releases/tags";
const VALID_TYPES = new Set([
  "debug",
  "base",
  "full",
  "audio",
  "video",
  "video_hw",
]);
const VALID_PLATFORMS = new Set([
  "android",
  "ios",
  "appletvos",
  "macos",
  "windows",
  "linux",
  "web",
  "wasm",
]);
const DEFAULT_CONFIG = Object.freeze({
  type: "base",
  gpl: false,
  small: true,
});
const LOCAL_ONLY_ENVIRONMENT_VARIABLE = "FFMPEG_KIT_EXTENDED_LOCAL_ONLY";

function fail(message) {
  throw new Error(`FFmpegKit [Config]: ${message}`);
}

function normalizePlatform(value) {
  const platform = String(value || "").toLowerCase();
  if (platform === "tvos") return "appletvos";
  if (!VALID_PLATFORMS.has(platform)) {
    fail(
      `Invalid platform: ${value}. Valid platforms are: ${[
        ...VALID_PLATFORMS,
      ].join(", ")}`
    );
  }
  return platform;
}

function normalizeArchitecture(value) {
  const architecture = String(value || "").toLowerCase();
  if (!architecture) return null;
  if (architecture === "x64" || architecture === "x86_64") return "x86_64";
  if (architecture === "arm64" || architecture === "aarch64") return "arm64";
  fail(`Unsupported architecture: ${value}`);
}

function remoteScheme(value) {
  const match = /^([a-z][a-z\d+.-]*):\/\//i.exec(value);
  return match ? `${match[1].toLowerCase()}:` : null;
}

function isRemote(value) {
  const scheme = remoteScheme(value);
  return scheme === "http:" || scheme === "https:";
}

function validateRemoteScheme(value) {
  const scheme = remoteScheme(value);
  if (scheme && scheme !== "http:" && scheme !== "https:") {
    fail(
      `Unsupported remote URL scheme "${scheme}"; only http:// and https:// URLs are supported.`
    );
  }
}

function isLocalArtifactOnlyEnabled(environment = process.env) {
  return (
    String(environment[LOCAL_ONLY_ENVIRONMENT_VARIABLE] || "").toLowerCase() ===
    "true"
  );
}

function validateLocalArtifactSelection({ platform, value, localOnly }) {
  if (!localOnly) return;
  if (value === undefined || value === null || String(value).trim() === "") {
    fail(
      `Local-only artifact validation for ${platform} requires an explicit local bundle override; ` +
        "default and remote resolution are disabled."
    );
  }
  validateRemoteScheme(String(value));
  if (isRemote(String(value))) {
    fail(
      `Local-only artifact validation for ${platform} rejects remote bundle overrides; ` +
        "configure a local filesystem bundle instead."
    );
  }
}

function findConfig(startDir) {
  let current = path.resolve(startDir);
  while (true) {
    const candidate = path.join(current, CONFIG_FILE_NAME);
    if (fs.existsSync(candidate)) return candidate;
    const parent = path.dirname(current);
    if (parent === current) return null;
    current = parent;
  }
}

function loadConfig(appRoot) {
  const resolvedAppRoot = path.resolve(appRoot || process.cwd());
  const configPath = findConfig(resolvedAppRoot);
  if (!configPath) {
    return {
      appRoot: resolvedAppRoot,
      configPath: null,
      config: { ...DEFAULT_CONFIG },
      usedDefaultConfig: true,
    };
  }

  let parsed;
  try {
    parsed = JSON.parse(fs.readFileSync(configPath, "utf8"));
  } catch (error) {
    fail(`Failed to parse ${configPath}: ${error.message}`);
  }

  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    fail(`${configPath} must contain a JSON object.`);
  }

  return {
    appRoot: path.dirname(configPath),
    configPath,
    config: { ...DEFAULT_CONFIG, ...parsed },
    usedDefaultConfig: false,
  };
}

function createCacheKey(value) {
  return crypto.createHash("sha256").update(value).digest("hex").slice(0, 16);
}

function resolveConfig({
  appRoot,
  platform,
  architecture,
  localOnly = isLocalArtifactOnlyEnabled(),
}) {
  const targetPlatform = normalizePlatform(platform);
  const targetArchitecture = normalizeArchitecture(architecture);
  const loaded = loadConfig(appRoot);
  const config = loaded.config;

  let type = String(config.type || DEFAULT_CONFIG.type);
  if (type === "streaming") type = "video";
  if (!VALID_TYPES.has(type)) {
    fail(
      `Invalid bundle type: ${type}. Valid types are: ${[...VALID_TYPES].join(
        ", "
      )}`
    );
  }

  const gpl = config.gpl === true;
  const small = config.small === true;
  const license = gpl ? "gpl" : "lgpl";
  const overrideValue =
    config[targetPlatform] ??
    (targetPlatform === "web"
      ? config.wasm
      : targetPlatform === "wasm"
      ? config.web
      : undefined);
  validateLocalArtifactSelection({
    platform: targetPlatform,
    value: overrideValue,
    localOnly,
  });

  const result = {
    appRoot: loaded.appRoot,
    configPath: loaded.configPath,
    usedDefaultConfig: loaded.usedDefaultConfig,
    platform: targetPlatform,
    architecture: targetArchitecture,
    type,
    gpl,
    small,
    license,
    version: BINARY_VERSION,
    override: null,
    artifact: null,
    filename: null,
    url: null,
    cacheKey: null,
    checksum: null,
  };

  if (overrideValue !== undefined && overrideValue !== null) {
    const value = String(overrideValue).trim();
    if (!value) fail(`The ${targetPlatform} override cannot be empty.`);
    validateRemoteScheme(value);

    if (isRemote(value)) {
      let filename;
      try {
        filename = path.basename(new URL(value).pathname);
      } catch (_) {
        filename = path.basename(value);
      }
      if (!filename) fail(`Could not determine a filename from ${value}`);
      result.override = { kind: "remote", value };
      result.filename = filename;
      result.url = value;
      result.cacheKey = createCacheKey(`remote:${value}`);
      return result;
    }

    const resolvedPath = path.isAbsolute(value)
      ? path.normalize(value)
      : path.resolve(loaded.appRoot, value);
    result.override = { kind: "local", value, resolvedPath };
    result.filename = path.basename(resolvedPath);
    result.cacheKey = createCacheKey(`local:${resolvedPath}`);
    return result;
  }

  const currentType = type === "debug" ? "base" : type;
  if (targetPlatform === "android") {
    const parts = ["bundle", currentType, "shared"];
    if (type === "debug") {
      parts.push("debug");
    } else if (small) {
      parts.push("small");
    }
    parts.push(license);

    const artifactId = parts.join("-");
    result.artifact = artifactId;
    result.filename = `${artifactId}-release.aar`;
    result.url = `${BASE_RELEASE_URL}/v${BINARY_VERSION}-${targetPlatform}/${result.filename}`;
    result.cacheKey = createCacheKey(`official:${result.url}`);
    result.checksum = {
      method: "github-release-digest",
      releaseApiUrl: `${RELEASE_API_URL}/v${BINARY_VERSION}-${targetPlatform}`,
      assetName: result.filename,
    };
    return result;
  }

  if (
    targetPlatform === "ios" ||
    targetPlatform === "appletvos" ||
    targetPlatform === "macos"
  ) {
    const parts = ["bundle", currentType, targetPlatform, "universal"];
    if (type === "debug") {
      parts.push("debug");
    } else if (small) {
      parts.push("small");
    }
    parts.push(license);

    result.artifact = parts.join("-");
    result.filename = `${result.artifact}.xcframework.zip`;
    result.url = `${BASE_RELEASE_URL}/v${BINARY_VERSION}-${targetPlatform}/${result.filename}`;
    result.cacheKey = createCacheKey(`official:${result.url}`);
    result.checksum = {
      method: "github-release-digest",
      releaseApiUrl: `${RELEASE_API_URL}/v${BINARY_VERSION}-${targetPlatform}`,
      assetName: result.filename,
    };
    return result;
  }

  if (targetPlatform === "web" || targetPlatform === "wasm") {
    if (type === "debug") {
      fail(
        `The prebuilt Web debug bundle for FFmpegKit binary ${BINARY_VERSION} is not browser-compatible. Use type "base" for Web or provide an explicit web/wasm custom override.`
      );
    }

    const parts = ["bundle", type, "wasm", "wasm32", "static"];
    if (small) {
      parts.push("small");
    }
    parts.push(license);

    result.platform = targetPlatform;
    result.architecture = "wasm32";
    result.artifact = parts.join("-");
    result.filename = `${result.artifact}.zip`;
    result.url = `${BASE_RELEASE_URL}/v${BINARY_VERSION}-wasm/${result.filename}`;
    result.cacheKey = createCacheKey(`official:${result.url}`);
    result.checksum = {
      method: "github-release-digest",
      releaseApiUrl: `${RELEASE_API_URL}/v${BINARY_VERSION}-wasm`,
      assetName: result.filename,
    };
    return result;
  }

  const arch = targetArchitecture || "x86_64";
  const parts = ["bundle", currentType, targetPlatform, arch, "shared"];
  if (type === "debug") {
    parts.push("debug");
  } else if (small) {
    parts.push("small");
  }
  parts.push(license);

  result.artifact = parts.join("-");
  result.filename = `${result.artifact}.zip`;
  result.url = `${BASE_RELEASE_URL}/v${BINARY_VERSION}-${targetPlatform}/${result.filename}`;
  result.cacheKey = createCacheKey(`official:${result.url}`);
  result.checksum = {
    method: "github-release-digest",
    releaseApiUrl: `${RELEASE_API_URL}/v${BINARY_VERSION}-${targetPlatform}`,
    assetName: result.filename,
  };
  return result;
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
  return args;
}

if (require.main === module) {
  try {
    const args = parseArgs(process.argv.slice(2));
    if (!args.platform) fail("--platform is required.");
    const resolution = resolveConfig({
      appRoot: args["app-root"] || process.env.FFMPEG_KIT_EXTENDED_APP_ROOT,
      platform: args.platform,
      architecture: args.architecture,
    });

    const quiet = args.quiet === "true";
    if (!quiet) {
      if (resolution.usedDefaultConfig) {
        console.error(
          'FFmpegKit [Config]: No ffmpeg-kit-extended.config.json found. Using default "base" LGPL small build.'
        );
      } else {
        console.error(`FFmpegKit [Config]: Using ${resolution.configPath}`);
      }
      if (resolution.type === "full") {
        console.error(
          "FFmpegKit [Config]: Full bundle selected. Review the included libraries and resulting application size before shipping."
        );
      }
    }

    process.stdout.write(`${JSON.stringify(resolution)}\n`);
  } catch (error) {
    console.error(error.message || String(error));
    process.exit(1);
  }
}

module.exports = {
  BINARY_VERSION,
  CONFIG_FILE_NAME,
  DEFAULT_CONFIG,
  LOCAL_ONLY_ENVIRONMENT_VARIABLE,
  isLocalArtifactOnlyEnabled,
  resolveConfig,
  validateLocalArtifactSelection,
};
