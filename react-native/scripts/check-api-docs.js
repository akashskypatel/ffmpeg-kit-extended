#!/usr/bin/env node

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawnSync} = require('node:child_process');

const packageRoot = path.resolve(__dirname, '..');
const committedDocs = path.join(packageRoot, 'doc', 'api');
const typedocEntry = path.join(
  packageRoot,
  'node_modules',
  'typedoc',
  'bin',
  'typedoc',
);

function normalizeLineEndings(value) {
  return value.replace(/\r\n?/g, '\n');
}

function collectFiles(root) {
  const files = new Map();

  function visit(directory) {
    for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory()) {
        visit(absolute);
      } else if (entry.isFile()) {
        const relative = path.relative(root, absolute).split(path.sep).join('/');
        files.set(relative, normalizeLineEndings(fs.readFileSync(absolute, 'utf8')));
      }
    }
  }

  if (fs.existsSync(root)) visit(root);
  return files;
}

function compareTrees(expectedRoot, actualRoot) {
  const expected = collectFiles(expectedRoot);
  const actual = collectFiles(actualRoot);
  const added = [];
  const missing = [];
  const changed = [];

  for (const relative of [...actual.keys()].sort()) {
    if (!expected.has(relative)) {
      added.push(relative);
    } else if (expected.get(relative) !== actual.get(relative)) {
      changed.push(relative);
    }
  }
  for (const relative of [...expected.keys()].sort()) {
    if (!actual.has(relative)) missing.push(relative);
  }

  return {added, missing, changed};
}

function printDifferences(differences) {
  for (const [label, paths] of Object.entries(differences)) {
    if (paths.length === 0) continue;
    console.error(`${label}:`);
    for (const relative of paths) console.error(`  ${relative}`);
  }
}

function run() {
  if (!fs.existsSync(typedocEntry)) {
    console.error(`TypeDoc entry point not found: ${typedocEntry}`);
    return 1;
  }
  if (!fs.existsSync(committedDocs)) {
    console.error(`Committed API documentation directory not found: ${committedDocs}`);
    return 1;
  }

  const temporaryRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), 'ffmpeg-kit-api-docs-'),
  );
  try {
    const generatedDocs = path.join(temporaryRoot, 'api');
    const result = spawnSync(
      process.execPath,
      [typedocEntry, '--options', path.join(packageRoot, 'typedoc.json'), '--out', generatedDocs],
      {
        cwd: packageRoot,
        encoding: 'utf8',
        stdio: 'inherit',
        windowsHide: true,
      },
    );
    if (result.error) {
      console.error(`Unable to run TypeDoc: ${result.error.message}`);
      return 1;
    }
    if (result.status !== 0) {
      return result.status ?? 1;
    }

    const differences = compareTrees(committedDocs, generatedDocs);
    if (Object.values(differences).some(paths => paths.length > 0)) {
      printDifferences(differences);
      console.error(
        'Committed React Native API documentation is stale; run `npm run docs:api` and review the generated changes.',
      );
      return 1;
    }

    console.log(
      `React Native API documentation is current (${collectFiles(committedDocs).size} files; line endings normalized for comparison).`,
    );
    return 0;
  } finally {
    fs.rmSync(temporaryRoot, {recursive: true, force: true});
  }
}

module.exports = {collectFiles, compareTrees, normalizeLineEndings};

if (require.main === module) process.exitCode = run();
