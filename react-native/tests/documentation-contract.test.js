const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const packageRoot = path.resolve(__dirname, '..');
const read = relativePath =>
  fs.readFileSync(path.join(packageRoot, relativePath), 'utf8');

test('README describes FFplay monitoring queries and awaited controls', () => {
  const readme = read('README.md');

  assert.match(
    readme,
    /Playback Monitoring.*position and video-dimension queries/s,
  );
  assert.doesNotMatch(readme, /Position and video dimension streams/);
  assert.match(
    readme,
    /await session\.pause\(\);[\s\S]*await session\.seek\(10\);[\s\S]*await session\.resume\(\);[\s\S]*await session\.setVolume\(0\.5\);/,
  );
});

test('FFplay current-session documentation describes newest unsettled ownership', () => {
  const source = read('src/ffplay-kit.ts');

  assert.match(source, /newest submitted high-level FFplay session/);
  assert.match(source, /execution Promise remains unsettled/);
  assert.match(source, /falls back to the next newest unsettled session/);
  assert.doesNotMatch(source, /remains current until this method's Promise settles/);
});

test('generated API reference covers the supported root inventory', () => {
  const apiRoot = path.join(packageRoot, 'doc', 'api');
  const expectedPages = [
    'classes/FFmpegKit.md',
    'classes/FFmpegKitConfig.md',
    'classes/FFmpegKitExtended.md',
    'classes/FFmpegSession.md',
    'classes/FFplayKit.md',
    'classes/FFplaySession.md',
    'classes/FFprobeKit.md',
    'classes/FFprobeSession.md',
    'classes/MediaInformation.md',
    'classes/MediaInformationSession.md',
    'classes/Session.md',
    'classes/SessionCancelledException.md',
    'classes/SessionQueueManager.md',
    'functions/FFplayView.md',
    'functions/argumentsToString.md',
    'functions/parseArguments.md',
    'functions/parseSessionJson.md',
    'functions/parseSessionsJson.md',
    'functions/sessionFromSnapshot.md',
    'interfaces/FFmpegKitInitializeOptions.md',
    'interfaces/SessionSnapshot.md',
    'type-aliases/NativeFFmpegKitExtendedLogEvent.md',
    'type-aliases/NativeFFmpegKitExtendedSpec.md',
    'variables/NativeFFmpegKitExtended.md',
  ];

  assert.equal(fs.existsSync(path.join(apiRoot, 'README.md')), true);
  for (const relativePath of expectedPages) {
    assert.equal(
      fs.existsSync(path.join(apiRoot, relativePath)),
      true,
      `missing generated API page: ${relativePath}`,
    );
  }
});

test('generated API reference excludes internal lifecycle and queue seams', () => {
  const apiRoot = path.join(packageRoot, 'doc', 'api');
  const markdown = [];
  const visit = directory => {
    for (const entry of fs.readdirSync(directory, {withFileTypes: true})) {
      const absolute = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(absolute);
      else if (entry.isFile() && entry.name.endsWith('.md')) {
        markdown.push(fs.readFileSync(absolute, 'utf8'));
      }
    }
  };
  visit(apiRoot);
  const generated = markdown.join('\n');

  for (const internalName of [
    'isRestoredRunning',
    'observeRestoredRunning',
    'prepareForExecution',
    'pollRestoredCallbacks',
    'settleRestoredObservation',
    'releaseRestoredHandle',
    'invalidateRestoredObservation',
    'reportRestoredObserverError',
    'executeSession',
    'cancelQueued',
    'findManagedSessionById',
    'isSessionActiveById',
    'cancelBySessionId',
  ]) {
    assert.doesNotMatch(generated, new RegExp(`\\b${internalName}\\b`));
  }

  assert.match(generated, /native `src\/index\.ts`|native `src\/index\.ts` only/);
  assert.match(generated, /src\/index\.web\.ts/);
  assert.match(generated, /assetBaseUrl/);

  for (const privateTypeName of [
    'RestoredSessionObservationTarget',
    'CancellableSession',
    'MaybePromise',
  ]) {
    assert.doesNotMatch(generated, new RegExp(`\\b${privateTypeName}\\b`));
  }
});

test('advanced native bridge docs expose a stable type-only contract', () => {
  const apiRoot = path.join(packageRoot, 'doc', 'api');
  const nativePage = read('doc/api/variables/NativeFFmpegKitExtended.md');
  const contractPage = read(
    'doc/api/type-aliases/NativeFFmpegKitExtendedSpec.md'
  );
  const eventPage = read(
    'doc/api/type-aliases/NativeFFmpegKitExtendedLogEvent.md'
  );

  assert.equal(
    fs.existsSync(
      path.join(apiRoot, 'type-aliases/NativeFFmpegKitExtendedSpec.md')
    ),
    true
  );
  assert.match(nativePage, /NativeFFmpegKitExtendedSpec/);
  assert.doesNotMatch(
    nativePage,
    /> \\*\\*NativeFFmpegKitExtended\\*\\*: `Spec`/
  );
  for (const methodName of [
    'initialize',
    'createFFmpegSession',
    'getSessionJson',
    'ffplayPause',
    'clearSessions',
  ]) {
    assert.match(contractPage, new RegExp(`\\b${methodName}\\b`));
  }
  assert.match(eventPage, /sessionId/);
  assert.match(nativePage, /src\/index\.web\.ts/);
});

test('generated constructors distinguish facades from native session wrappers', () => {
  for (const className of [
    'FFmpegKit',
    'FFprobeKit',
    'FFplayKit',
    'FFmpegKitConfig',
    'FFmpegKitExtended',
    'SessionQueueManager',
  ]) {
    const page = read(`doc/api/classes/${className}.md`);
    assert.doesNotMatch(page, /^## Constructors/m, `${className} hides its constructor`);
  }

  const sessionGuidance = [
    ['FFmpegSession', 'FFmpegKit'],
    ['FFprobeSession', 'FFprobeKit'],
    ['MediaInformationSession', 'FFprobeKit'],
    ['FFplaySession', 'FFplayKit'],
  ];
  for (const [className, factoryName] of sessionGuidance) {
    const page = read(`doc/api/classes/${className}.md`);
    assert.match(page, /existing valid native .*session identity/);
    assert.match(page, /arbitrary ID does not create a native\s+session/);
    assert.match(page, new RegExp(`${factoryName}[\\s\\S]*factory`));
    assert.match(page, /history APIs/);
  }
  assert.match(
    read('doc/api/classes/MediaInformationSession.md'),
    /timeoutMs[\s\S]*measured[\s\S]*milliseconds/
  );
  assert.match(
    read('doc/api/classes/FFplaySession.md'),
    /timeoutMs[\s\S]*measured[\s\S]*milliseconds/
  );
});
