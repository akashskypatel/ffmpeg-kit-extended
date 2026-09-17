'use strict';

const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const fs = require('node:fs');
const http = require('node:http');
const os = require('node:os');
const path = require('node:path');
const {afterEach, test} = require('node:test');

const {ensureArtifact} = require('../scripts/download-ffmpeg-kit-artifact.js');

const servers = [];
const temporaryRoots = [];

function startServer(handler) {
  return new Promise((resolve, reject) => {
    const server = http.createServer(handler);
    servers.push(server);
    server.once('error', reject);
    server.listen(0, '127.0.0.1', () => {
      resolve(`http://127.0.0.1:${server.address().port}`);
    });
  });
}

function sha256(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

afterEach(async () => {
  await Promise.all(servers.splice(0).map(server => new Promise(resolve => server.close(resolve))));
  for (const root of temporaryRoots.splice(0)) {
    fs.rmSync(root, {recursive: true, force: true});
  }
});

test('checksum-free downloads refresh instead of reusing an unverified cache', async () => {
  let requests = 0;
  const serverUrl = await startServer((_request, response) => {
    requests += 1;
    response.end(requests === 1 ? 'first artifact' : 'refreshed artifact');
  });
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-download-'));
  temporaryRoots.push(root);
  const output = path.join(root, 'build.zip');
  const options = {url: `${serverUrl}/build.zip`, output, retries: 1, timeoutMs: 1000, quiet: true};

  await ensureArtifact(options);
  await ensureArtifact({...options, reuseCached: false});

  assert.equal(requests, 2);
  assert.equal(fs.readFileSync(output, 'utf8'), 'refreshed artifact');
});

test('checksum validation removes corrupt cached artifacts and reuses valid ones', async () => {
  const validArtifact = Buffer.from('valid artifact');
  const invalidArtifact = Buffer.from('invalid artifact');
  let artifact = invalidArtifact;
  let artifactRequests = 0;
  let checksumRequests = 0;
  const expected = sha256(validArtifact);
  const serverUrl = await startServer((request, response) => {
    if (request.url === '/checksum') {
      checksumRequests += 1;
      response.end(`${expected}  build.zip\n`);
      return;
    }
    artifactRequests += 1;
    response.end(artifact);
  });
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-download-'));
  temporaryRoots.push(root);
  const output = path.join(root, 'build.zip');
  const options = {
    url: `${serverUrl}/build.zip`,
    output,
    checksum: {method: 'sidecar', url: `${serverUrl}/checksum`},
    retries: 1,
    timeoutMs: 1000,
    quiet: true,
  };

  await assert.rejects(ensureArtifact(options), /SHA256 hash mismatch/);
  assert.equal(fs.existsSync(output), false);

  artifact = validArtifact;
  await ensureArtifact(options);
  artifact = Buffer.from('replacement artifact');
  await ensureArtifact(options);

  assert.equal(artifactRequests, 2);
  assert.equal(checksumRequests, 3);
  assert.equal(fs.readFileSync(output).toString(), validArtifact.toString());
});

test('rejects unsupported download URL schemes', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'ffmpeg-kit-download-'));
  temporaryRoots.push(root);
  const output = path.join(root, 'build.zip');

  await assert.rejects(
    ensureArtifact({
      url: 'ftp://example.com/build.zip',
      output,
      retries: 1,
      timeoutMs: 1000,
      quiet: true,
    }),
    /Unsupported download URL scheme "ftp:"; only http:\/\/ and https:\/\/ URLs are supported\./,
  );
  assert.equal(fs.existsSync(output), false);
});
