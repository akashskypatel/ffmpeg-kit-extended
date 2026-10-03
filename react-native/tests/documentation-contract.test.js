const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const typescript = require('typescript');

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
  assert.match(contractPage, /^### initialize\(\)$/m);
  assert.match(contractPage, /^### createFFmpegSession\(\)$/m);
  assert.match(contractPage, /^### getSessionJson\(\)$/m);
  assert.match(contractPage, /^### ffplayPause\(\)$/m);
  assert.match(contractPage, /^### clearSessions\(\)$/m);
  assert.match(eventPage, /sessionId/);
  assert.match(nativePage, /src\/index\.web\.ts/);
});

test('advanced native bridge docs cover every Codegen member and scalar contract', () => {
  const source = read('src/NativeFFmpegKitExtended.ts');
  const contractPage = read(
    'doc/api/type-aliases/NativeFFmpegKitExtendedSpec.md'
  );
  const eventPage = read(
    'doc/api/type-aliases/NativeFFmpegKitExtendedLogEvent.md'
  );
  const apiIndex = read('doc/api/README.md');
  const sourceFile = typescript.createSourceFile(
    'NativeFFmpegKitExtended.ts',
    source,
    typescript.ScriptTarget.Latest,
    true,
    typescript.ScriptKind.TS
  );
  const findDeclaration = (predicate, name) => {
    let declaration;
    const visit = node => {
      if (predicate(node) && node.name && node.name.text === name) {
        declaration = node;
        return;
      }
      typescript.forEachChild(node, visit);
    };
    visit(sourceFile);
    return declaration;
  };
  const codegenDeclaration = findDeclaration(
    typescript.isInterfaceDeclaration,
    'Spec'
  );
  const publicDeclaration = findDeclaration(
    typescript.isTypeAliasDeclaration,
    'NativeFFmpegKitExtendedSpec'
  );
  assert.ok(codegenDeclaration, 'Codegen Spec declaration is present');
  assert.ok(publicDeclaration, 'public native contract declaration is present');
  assert.ok(
    typescript.isTypeLiteralNode(publicDeclaration.type),
    'public native contract is an explicit object type'
  );
  const memberName = member => member.name && member.name.getText(sourceFile);
  const codegenMembers = codegenDeclaration.members.map(memberName).sort();
  const publicMembers = publicDeclaration.type.members.map(memberName).sort();
  assert.deepEqual(
    publicMembers,
    codegenMembers,
    'public contract and Codegen own member inventories match exactly'
  );
  for (const member of publicMembers) {
    assert.match(
      contractPage,
      new RegExp('^### ' + member + '(?:\\(\\))?$', 'm'),
      'generated contract page exposes ' + member + ' as a member heading'
    );
  }

  const markdownTick = String.fromCharCode(96);
  const markdownType = value => markdownTick + value + markdownTick;
  const promiseVoid =
    markdownType('Promise') + '\\<' + markdownType('void') + '\\>';
  const expectedSignatures = [
    ['initialize', '**initialize**(): ' + promiseVoid],
    [
      'createFFmpegSession',
      '**createFFmpegSession**(' + markdownType('command') + '): ' + markdownType('number'),
    ],
    [
      'executeSessionAsync',
      '**executeSessionAsync**(' +
        markdownType('sessionId') +
        ', ' +
        markdownType('timeoutMs') +
        '): ' +
        promiseVoid,
    ],
    [
      'getSessionJson',
      '**getSessionJson**(' + markdownType('sessionId') + '): ' + markdownType('string'),
    ],
    [
      'ffplayPause',
      '**ffplayPause**(' + markdownType('sessionId') + '): ' + promiseVoid,
    ],
    [
      'setLogLevel',
      '**setLogLevel**(' + markdownType('level') + '): ' + promiseVoid,
    ],
    ['getFFmpegVersion', '**getFFmpegVersion**(): ' + markdownType('string')],
    ['clearSessions', '**clearSessions**(): ' + promiseVoid],
    [
      'enableDebugLog',
      '**enableDebugLog**(' + markdownType('sessionId') + '): ' + promiseVoid,
    ],
  ];
  for (const [methodName, signature] of expectedSignatures) {
    assert.notEqual(
      contractPage.indexOf(signature),
      -1,
      'generated contract page contains the ' + methodName + ' signature'
    );
  }

  assert.doesNotMatch(contractPage, /keyof\s+Spec/);
  assert.doesNotMatch(contractPage, /\b(?:Spec|Double|Int32)\b/);
  for (const [fieldName, fieldType] of [
    ['sessionId', 'number'],
    ['sequence', 'number'],
    ['level', 'number'],
    ['message', 'string'],
  ]) {
    assert.notEqual(
      eventPage.indexOf('**' + fieldName + '**: ' + markdownType(fieldType)),
      -1,
      'public log event documents ' + fieldName + ' as ' + fieldType
    );
  }
  assert.doesNotMatch(eventPage, /\b(?:Double|Int32)\b/);

  const categoryStart = apiIndex.indexOf('## Advanced / native bridge');
  assert.notEqual(categoryStart, -1, 'advanced native bridge category is present');
  const categoryEnd = apiIndex.indexOf('\n## ', categoryStart + 1);
  const category = apiIndex.slice(
    categoryStart,
    categoryEnd === -1 ? undefined : categoryEnd
  );
  for (const symbol of [
    'NativeFFmpegKitExtended',
    'NativeFFmpegKitExtendedSpec',
    'NativeFFmpegKitExtendedLogEvent',
  ]) {
    assert.notEqual(
      category.indexOf(symbol),
      -1,
      symbol + ' is grouped in the advanced native bridge category'
    );
  }
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
