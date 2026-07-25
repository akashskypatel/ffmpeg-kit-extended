'use strict';

const crypto = require('crypto');
const fs = require('fs');
const http = require('http');
const https = require('https');
const path = require('path');

const DEFAULT_RETRIES = 3;
const DEFAULT_TIMEOUT_MS = 30000;
const MAX_REDIRECTS = 10;

function fail(message) {
  throw new Error(`FFmpegKit [Download]: ${message}`);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function requestBuffer(url, {timeoutMs = DEFAULT_TIMEOUT_MS, redirects = 0} = {}) {
  return new Promise((resolve, reject) => {
    if (redirects > MAX_REDIRECTS) {
      reject(new Error(`Too many redirects while requesting ${url}`));
      return;
    }

    const client = url.startsWith('https:') ? https : http;
    const request = client.get(
      url,
      {
        headers: {
          'User-Agent': 'ffmpeg-kit-extended-react-native',
          Accept: 'application/vnd.github+json, */*',
        },
      },
      (response) => {
        const status = response.statusCode || 0;
        if (status >= 300 && status < 400 && response.headers.location) {
          response.resume();
          const redirectUrl = new URL(response.headers.location, url).toString();
          resolve(requestBuffer(redirectUrl, {timeoutMs, redirects: redirects + 1}));
          return;
        }
        if (status < 200 || status >= 300) {
          response.resume();
          reject(new Error(`HTTP ${status} for ${url}`));
          return;
        }

        const chunks = [];
        response.on('data', (chunk) => chunks.push(chunk));
        response.on('end', () => resolve(Buffer.concat(chunks)));
      },
    );

    request.setTimeout(timeoutMs, () => {
      request.destroy(new Error(`Request timed out after ${timeoutMs}ms: ${url}`));
    });
    request.on('error', reject);
  });
}

async function withRetries(operation, {retries = DEFAULT_RETRIES, label, quiet = false} = {}) {
  let lastError;
  for (let attempt = 1; attempt <= retries; attempt += 1) {
    try {
      return await operation(attempt);
    } catch (error) {
      lastError = error;
      if (attempt >= retries) break;
      if (!quiet) {
        console.error(
          `FFmpegKit [Download]: ${label} failed (attempt ${attempt}/${retries}): ${error.message}`,
        );
      }
      await sleep(Math.min(1000 * attempt, 3000));
    }
  }
  throw lastError;
}

async function downloadToFile(url, target, options = {}) {
  const tempTarget = `${target}.downloading`;
  fs.mkdirSync(path.dirname(target), {recursive: true});
  fs.rmSync(tempTarget, {force: true});

  try {
    const data = await withRetries(
      () => requestBuffer(url, options),
      {...options, label: `Download ${url}`},
    );
    fs.writeFileSync(tempTarget, data);
    fs.renameSync(tempTarget, target);
  } catch (error) {
    fs.rmSync(tempTarget, {force: true});
    throw error;
  }
}

function computeSha256(file) {
  const hash = crypto.createHash('sha256');
  hash.update(fs.readFileSync(file));
  return hash.digest('hex').toLowerCase();
}

async function fetchExpectedSha256(checksum, options = {}) {
  if (!checksum) return null;

  try {
    if (checksum.method === 'sidecar') {
      const content = await withRetries(
        () => requestBuffer(checksum.url, options),
        {...options, label: `Checksum ${checksum.url}`},
      );
      const first = content.toString('utf8').trim().split(/\s+/)[0];
      return first ? first.toLowerCase() : null;
    }

    if (checksum.method === 'github-release-digest') {
      const content = await withRetries(
        () => requestBuffer(checksum.releaseApiUrl, options),
        {...options, label: `Release metadata ${checksum.releaseApiUrl}`},
      );
      const release = JSON.parse(content.toString('utf8'));
      const asset = Array.isArray(release.assets)
        ? release.assets.find((candidate) => candidate.name === checksum.assetName)
        : null;
      if (!asset || !asset.digest) return null;
      const digest = String(asset.digest).toLowerCase();
      return digest.startsWith('sha256:') ? digest.slice('sha256:'.length) : digest;
    }

    fail(`Unsupported checksum method: ${checksum.method}`);
  } catch (error) {
    if (!options.quiet) {
      console.error(
        `FFmpegKit [Download]: Could not retrieve SHA256 checksum; skipping verification: ${error.message}`,
      );
    }
    return null;
  }
}

async function verifyFile(file, checksum, options = {}) {
  const expected = await fetchExpectedSha256(checksum, options);
  if (!expected) return {verified: false, reason: 'missing-checksum'};

  const actual = computeSha256(file);
  if (actual !== expected) {
    fs.rmSync(file, {force: true});
    fail(`SHA256 hash mismatch for ${file}: expected ${expected}, got ${actual}`);
  }
  return {verified: true, expected, actual};
}

async function ensureArtifact({
  url,
  output,
  checksum = null,
  retries = DEFAULT_RETRIES,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  quiet = false,
}) {
  const options = {retries, timeoutMs, quiet};
  const tempTarget = `${output}.downloading`;
  fs.rmSync(tempTarget, {force: true});

  if (fs.existsSync(output) && fs.statSync(output).size > 0) {
    if (checksum) {
      try {
        const result = await verifyFile(output, checksum, options);
        if (!quiet && result.verified) {
          console.log(`FFmpegKit [Download]: SHA256 verification passed for cached ${output}`);
        }
        if (!quiet && !result.verified) {
          console.log(`FFmpegKit [Download]: No SHA256 hash found; using cached ${output}`);
        }
        return output;
      } catch (error) {
        fs.rmSync(output, {force: true});
        if (!quiet) {
          console.error(`FFmpegKit [Download]: Removing corrupt cached artifact ${output}`);
        }
      }
    } else {
      if (!quiet) console.log(`FFmpegKit [Download]: Using cached ${output}`);
      return output;
    }
  }

  try {
    if (!quiet) console.log(`FFmpegKit [Download]: Downloading ${url}`);
    await downloadToFile(url, output, options);
    if (checksum) {
      const result = await verifyFile(output, checksum, options);
      if (!quiet && result.verified) {
        console.log('FFmpegKit [Download]: SHA256 verification passed');
      } else if (!quiet) {
        console.log('FFmpegKit [Download]: No SHA256 hash found; skipping verification');
      }
    }
    return output;
  } catch (error) {
    fs.rmSync(tempTarget, {force: true});
    if (fs.existsSync(output) && (!checksum || fs.statSync(output).size === 0)) {
      fs.rmSync(output, {force: true});
    }
    throw error;
  }
}

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (!key.startsWith('--')) fail(`Unknown argument: ${key}`);
    const value = argv[index + 1];
    if (value === undefined || value.startsWith('--')) fail(`Missing value for ${key}`);
    args[key.slice(2)] = value;
    index += 1;
  }
  return args;
}

if (require.main === module) {
  (async () => {
    try {
      const args = parseArgs(process.argv.slice(2));
      if (!args.url) fail('--url is required.');
      if (!args.output) fail('--output is required.');

      let checksum = null;
      if (args['checksum-method']) {
        checksum = {method: args['checksum-method']};
        if (checksum.method === 'sidecar') checksum.url = args['checksum-url'];
        if (checksum.method === 'github-release-digest') {
          checksum.releaseApiUrl = args['release-api-url'];
          checksum.assetName = args['asset-name'];
        }
      }

      await ensureArtifact({
        url: args.url,
        output: path.resolve(args.output),
        checksum,
        retries: Number(args.retries || DEFAULT_RETRIES),
        timeoutMs: Number(args['timeout-ms'] || DEFAULT_TIMEOUT_MS),
        quiet: args.quiet === 'true',
      });
    } catch (error) {
      console.error(error.message || String(error));
      process.exitCode = 1;
    }
  })();
}

module.exports = {
  computeSha256,
  downloadToFile,
  ensureArtifact,
  fetchExpectedSha256,
  verifyFile,
};
