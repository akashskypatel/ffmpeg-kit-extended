# Luna Plan — React Native Advanced Native-Bridge API Documentation Final Closure

Date: 2026-10-03  
Audience: Luna implementation/review model  
Repository: `akashskypatel/ffmpeg-kit-extended`  
Branch: `dev-wasm`  
Starting source authority: `a5d11102063710582895ee2425289bd06bb5bb80`

## Mission

Close the one remaining substantive React Native generated-API documentation defect without reopening already-closed runtime, queue, lifecycle, platform-native, Flutter, ABI, builder, or documentation-tooling work.

The current generated reference successfully hides internal observer/queue types and presents constructors correctly, but the advanced native bridge contract remains opaque:

```text
NativeFFmpegKitExtendedSpec = { [Key in keyof Spec]: Spec[Key] }
```

The final public reference must show the actual native-only methods/properties and signatures while React Native Codegen continues to consume its required `Spec extends TurboModule` declaration unchanged in semantic behavior.

## Hard boundaries

- Keep native ABI/runtime `0.11.2` frozen.
- Keep `libs/libffmpegkit` exactly at `b74da2c5d1e294b87d15d73a6687393729e932b3`.
- Do not edit Flutter.
- Do not edit React Native C++, Android, Apple, Windows, Web/Wasm runtime logic, or native configuration.
- Do not edit ManyLinux builders.
- Do not download or publish native artifacts.
- Do not run hosted Flutter/React Native acceptance workflows.
- Keep TypeDoc and `typedoc-plugin-markdown`; do not introduce another documentation generator.
- Keep `scripts/check-api-docs.js`; do not redesign the accepted cross-host drift mechanism.
- Keep `doc/api/**` generated-only. Never hand-edit generated Markdown.
- Do not add `doc` to npm `files`; the accepted project policy is committed GitHub-hosted Markdown.
- Keep `Spec` as React Native Codegen's interface name and preserve its Codegen-compatible declaration form.
- Do not solve the documentation problem by exporting the private Codegen `Spec` name directly.
- Production/test/comment names must be semantic. Do not put review/finding/goal IDs in code, tests, or user-facing docs.
- Record failures/retries/skips truthfully. Do not weaken strict validation to obtain green output.

## Starting evidence

Verified starting artifact:

- workflow run `37144478826`
- artifact `react-native-consumer-api-source-snapshot-37144478826`
- artifact ID `11282041436`
- GitHub artifact SHA-256 `e3bc6ebf982a2fe603d49e02b64f118d6ea87ebc901150a4ea344d57b1124d8c`
- embedded source SHA-256 `35cb1e88bbbf8ab13d27709083898d90aa5dfa88a9bd54f0b44a7e5eb7876062`
- `1138/1138` manifest entries verified
- zero symlinks
- `runtimeExecution=false`
- native submodule unchanged at the frozen SHA

Already closed:

- internal observer name leakage;
- queue-helper name leakage;
- facade/queue constructor presentation;
- session-wrapper constructor guidance;
- strict TypeDoc configuration;
- generated-doc drift tooling;
- relative generated Markdown links (568 checked, zero broken);
- package/runtime/native/Flutter boundaries.

## Goal tracker

| Goal | Objective | Expected production scope | Status |
| --- | --- | --- | --- |
| G1 | Replace the opaque mapped public bridge alias with an explicit documented consumer contract while preserving Codegen `Spec` | `react-native/src/NativeFFmpegKitExtended.ts` only | Pending |
| G2 | Strengthen documentation contracts so actual generated method/signature visibility and scalar self-containment are enforced | documentation tests + generated Markdown/config category metadata | Pending |
| G3 | Regenerate, run local type/docs/Codegen/package gates, prove zero runtime diff, and freeze one final exact source snapshot | generated docs/tests/tracker only | Pending |

---

# G1 — publish a genuinely self-contained advanced native bridge contract

## G1.1 Preserve the Codegen authority exactly

The existing React Native Codegen declaration remains the native generation authority:

```ts
export interface Spec extends TurboModule {
  ...
}
```

Do not rename it.

Do not change it to extend the consumer documentation type.

Do not move its members into another interface and leave `Spec` empty/inherited unless React Native Codegen's parser explicitly proves that form supported. The safest implementation is to leave the Codegen interface structurally where it is today.

All current Codegen member names and signatures must remain semantically identical.

## G1.2 Replace the mapped public alias

Current code is not sufficient for TypeDoc:

```ts
export type NativeFFmpegKitExtendedSpec = {
  [Key in keyof Spec]: Spec[Key];
};
```

It renders only the mapped expression and hides every method signature.

Replace it with an **explicit type-only object contract** containing the complete native consumer surface.

Preferred shape:

```ts
/**
 * Stable native-only contract for advanced integrations and diagnostics.
 *
 * Most applications should use the high-level wrappers. Direct use requires
 * the caller to preserve session lifetime, retained-handle, callback-demand,
 * and history rules normally owned by those wrappers.
 *
 * @category Advanced / native bridge
 */
export type NativeFFmpegKitExtendedSpec = {
  /** Initializes the selected native FFmpegKit runtime. */
  initialize(): Promise<void>;

  /** Consumes the synchronous native diagnostic for the same call boundary. */
  consumeSynchronousError(): string;

  /** Returns the wrapper/native build stamp. */
  getBuildStamp(): string;

  // ...every remaining native method/property with an accurate concise comment...
};
```

The public contract must contain the entire supported advanced native method inventory, including:

### Initialization / diagnostic

- `initialize`
- `consumeSynchronousError`
- `getBuildStamp`

### Session creation / execution / cancellation

- `createFFmpegSession`
- `createFFmpegSessionFromArguments`
- `createFFprobeSession`
- `createFFplaySession`
- `createFFplaySessionFromArguments`
- `createMediaInformationSession`
- `createMediaInformationSessionFromPath`
- `executeSessionAsync`
- `cancelSession`

### Log bridge

- `onLogEvent`
- `installLogBridge`
- `uninstallLogBridge`

### Session/history/callback data

- `getSessionJson`
- `getSessionState`
- `getLogsCount`
- `releaseSessionHandle`
- `abandonCreatedSession`
- `getSessionsJson`
- `getLastSessionJson`
- `getLogsJson`
- `getStatisticsJson`
- `getMediaInformationJson`

### FFplay

- `ffplayStart`
- `ffplayPause`
- `ffplayResume`
- `ffplayStop`
- `ffplaySeek`
- `ffplayGetPosition`
- `ffplaySetPosition`
- `ffplayGetDuration`
- `ffplayGetVideoWidth`
- `ffplayGetVideoHeight`
- `ffplayIsPlaying`
- `ffplayIsPaused`
- `ffplaySetVolume`
- `ffplayGetVolume`
- `ffplayHasVideoStream`

### Runtime configuration

- `enableRedirection`
- `disableRedirection`
- `setLogLevel`
- `getLogLevel`
- `logLevelToString`
- `setFontDirectory`
- `setEnvironmentVariable`
- `ignoreSignal`
- `setAudioOutputDevice`
- `listAudioOutputDevices`

### Build/license/features

- `getFFmpegVersion`
- `getFFmpegArchitecture`
- `getVersion`
- `getPackageName`
- `getExternalLibraries`
- `getBundleType`
- `isGpl`
- `isNonfree`
- `getRegisteredCodecs`
- `getRegisteredEncoders`
- `getRegisteredDecoders`
- `getRegisteredMuxers`
- `getRegisteredDemuxers`
- `getRegisteredFilters`
- `getRegisteredProtocols`
- `getRegisteredBitstreamFilters`
- `getBuildConfiguration`
- `getBuildDate`

### History/pipes/debug

- `setSessionHistorySize`
- `getSessionHistorySize`
- `clearSessions`
- `registerNewFFmpegPipe`
- `closeFFmpegPipe`
- `messagesInTransmit`
- `enableDebugLog`
- `disableDebugLog`
- `isDebugLogEnabled`
- `getDebugLog`
- `clearDebugLog`

Do not omit methods merely because most applications should not call them directly; the purpose of this advanced page is to document the complete native-only contract that the package already exports.

## G1.3 Make consumer scalar types self-contained

Keep the private Codegen payload exactly as required:

```ts
export type LogEvent = {
  sessionId: Double;
  sequence: Double;
  level: Int32;
  message: string;
};
```

For the stable public documentation type, prefer ordinary TypeScript scalars:

```ts
/** @category Advanced / native bridge */
export type NativeFFmpegKitExtendedLogEvent = {
  sessionId: number;
  sequence: number;
  level: number;
  message: string;
};
```

Reason:

- consumers see normal JavaScript numeric values;
- generated docs no longer contain unexplained `Double`/`Int32` names;
- the Codegen declaration remains untouched.

If React Native's local definitions make those aliases non-assignable to `number` in this package version, retain exact compatibility but document/export consumer-safe scalar aliases explicitly. Do not silently leave unresolved private Codegen type names in the public page.

## G1.4 Keep runtime output unchanged

Prefer to restore the Codegen-facing generic at the runtime expression:

```ts
TurboModuleRegistry.getEnforcing<Spec>('FFmpegKitExtended')
```

Expose the public type with an erased TypeScript assertion/annotation, for example conceptually:

```ts
export default TurboModuleRegistry.getEnforcing<Spec>(
  'FFmpegKitExtended'
) as NativeFFmpegKitExtendedSpec;
```

The exact formatting may follow project Prettier.

The emitted JavaScript call must remain behaviorally identical to the starting snapshot.

Do not add a wrapper/proxy object.

Do not copy methods at runtime.

Do not change module registration.

## G1.5 Add automatic signature parity

An explicit consumer contract duplicates type declarations, so source drift must be impossible to miss.

Add a compile-time parity assertion between the own Codegen `Spec` API and `NativeFFmpegKitExtendedSpec`.

One acceptable type-only shape is:

```ts
type NativeCodegenSurface = Omit<Spec, keyof TurboModule>;

type IsExactlyAssignable<A, B> =
  [A] extends [B]
    ? [B] extends [A]
      ? true
      : false
    : false;

type Assert<T extends true> = T;

type NativeContractParity = Assert<
  IsExactlyAssignable<NativeCodegenSurface, NativeFFmpegKitExtendedSpec>
>;
```

Use semantic internal names appropriate to the repository. These helpers must not be exported or appear in generated docs.

If `TurboModule` inheritance introduces a type-system edge that makes this exact helper unsuitable, use an equivalent non-emitting compile-time check or a TypeScript-AST test. The requirement is bidirectional key/signature parity, not this exact implementation.

Do **not** rely only on manually comparing method names.

## G1.6 Category metadata

Add:

```text
@category Advanced / native bridge
```

to both public bridge types so the generated index groups these together:

- `NativeFFmpegKitExtended`
- `NativeFFmpegKitExtendedSpec`
- `NativeFFmpegKitExtendedLogEvent`

The private `Spec` and `LogEvent` must remain excluded.

## G1.7 G1 source checks

Before moving on, verify from source:

1. Codegen `Spec` still directly extends `TurboModule`.
2. Existing Codegen method signatures did not change.
3. Public bridge contract explicitly contains every method/property.
4. Public log event is self-contained.
5. Runtime `getEnforcing` call is unchanged after type erasure.
6. No runtime wrapper/proxy was introduced.
7. Type parity compiles.
8. `Spec` remains the only intentional TypeDoc non-exported exception if still necessary.

---

# G2 — make the generated-document regression prove real method visibility

## G2.1 Current test weakness

The existing test currently passes because these strings occur in prose:

```text
initialize
createFFmpegSession
getSessionJson
ffplayPause
clearSessions
```

That does not prove that TypeDoc generated callable signatures.

Replace this weak assertion with structural Markdown checks.

## G2.2 Mandatory generated contract assertions

After generation, `NativeFFmpegKitExtendedSpec.md` must:

- **not** contain `keyof Spec`;
- **not** require a private `Spec` symbol to understand its shape;
- contain a generated members/methods section appropriate to the Markdown plugin's actual output;
- contain actual signatures for representative methods across every functional group.

At minimum assert semantic signature fragments, not bare names, for:

```text
initialize(): Promise<void>
createFFmpegSession(command: string)
executeSessionAsync(sessionId, timeoutMs)
getSessionJson(sessionId)
ffplayPause(sessionId)
setLogLevel(level)
getFFmpegVersion()
clearSessions(): Promise<void>
enableDebugLog(sessionId)
```

Use regexes tolerant of TypeDoc Markdown escaping/link formatting but strict enough to require parameter/return signature context.

## G2.3 Prefer full inventory coverage

Do not maintain another hand-written list of only five representatives.

Preferred test:

1. parse `src/NativeFFmpegKitExtended.ts` with the already-installed TypeScript compiler API;
2. locate the Codegen `Spec` declaration;
3. collect its own method/property member names;
4. locate the explicit `NativeFFmpegKitExtendedSpec` type declaration;
5. collect its member names;
6. assert exact set equality;
7. assert every public-contract member name appears as a generated member heading/signature in the TypeDoc Markdown.

The compile-time parity assertion remains the signature authority; this test proves generated-document visibility.

If using the TypeScript compiler API would make the test materially more complex than the existing suite conventions, keep the compile-time parity assertion and use a complete semantic member-name list generated from one declaration at test runtime. Do not revert to five prose words.

## G2.4 Public log-event contract assertions

Strengthen the event-page contract to require:

```text
sessionId: number
sequence: number
level: number
message: string
```

and reject:

```text
Double
Int32
```

unless the fallback public scalar-alias approach from G1.3 was required and those aliases are themselves generated/documented.

## G2.5 Category/index assertions

The generated root API index must group all three advanced bridge entries under `Advanced / native bridge`:

- runtime variable;
- public native spec type;
- public log-event type.

Do not hard-code exact surrounding whitespace beyond what is needed to establish the category membership.

## G2.6 Preserve existing closure contracts

Retain current tests proving:

- no `RestoredSessionObservationTarget` in generated docs;
- no `CancellableSession` in generated docs;
- no `MaybePromise` in generated docs;
- no constructors on static facades or `SessionQueueManager`;
- concrete session constructor guidance remains present;
- native-vs-Web notes remain present;
- generated supported root inventory remains present.

Do not delete existing coverage simply because G2 adds stronger assertions.

---

# G3 — regenerate, validate, prove zero runtime change, and freeze final source

## G3.1 Regenerate only through TypeDoc

From `react-native/`:

```text
npm run docs:api
npm run docs:api:check
```

Do not hand-edit generated Markdown.

Review the generated diff, especially:

```text
doc/api/README.md
doc/api/type-aliases/NativeFFmpegKitExtendedSpec.md
doc/api/type-aliases/NativeFFmpegKitExtendedLogEvent.md
doc/api/variables/NativeFFmpegKitExtended.md
```

If TypeDoc changes the public contract's output path because the implementation uses an interface rather than a type alias, update the documented inventory/tests consistently. Prefer keeping the existing exported symbol name stable.

## G3.2 Focused local gates

Run from `react-native/`:

```text
npm run typecheck
npm run test:compile
npm run docs:api
npm run docs:api:check
node --test tests/documentation-contract.test.js tests/documentation-drift.test.js
node --test tests/codegen-lifecycle.test.js
npm run lint
```

All TypeDoc validation warnings remain fatal.

Do not add a validation exception for the public consumer contract.

## G3.3 Package/declaration gates

Because this work touches exported type-only names/signatures, also run:

```text
npm run prepare
npm run test:pack-types
npm pack --dry-run
```

If the repository's normal dry-pack command uses additional flags, use the established equivalent.

Verify:

- `NativeFFmpegKitExtended` is typed as the stable public contract in emitted declarations;
- `NativeFFmpegKitExtendedSpec` is exported from the native type surface;
- the public contract does not require consumers to name/import private `Spec`;
- Web runtime exports remain unchanged;
- the npm `files` policy remains unchanged.

## G3.4 Full local Node regression

After focused gates pass:

```text
npm test
```

Record exact pass/fail/skip counts truthfully.

This task does not justify native platform rebuilds if the diff remains comments/types/tests/generated Markdown only.

## G3.5 Cross-host documentation determinism

Run the established WSL/Linux documentation drift gate:

```text
npm run docs:api:check
```

Use the existing environment and current locked dependencies.

Do not install a second documentation stack.

A Mac documentation check is optional unless the final diff introduces host-sensitive path/rendering behavior; the existing generator already passed Windows and WSL determinism.

## G3.6 Prove zero runtime-emitting change

The final source diff should be limited to:

```text
react-native/src/NativeFFmpegKitExtended.ts
react-native/tests/documentation-contract.test.js
react-native/doc/api/**
possibly typedoc category/config metadata only if directly required
tracker/.agent documentation
```

`NativeFFmpegKitExtended.ts` changes must be comments, type aliases/type helpers, type assertions/annotations, and other erased constructs only.

Do not change:

- method bodies;
- runtime control flow;
- backend registration;
- TurboModule name;
- runtime exports;
- native invocation semantics.

For the default native module expression, confirm the emitted module call remains equivalent to:

```js
TurboModuleRegistry.getEnforcing('FFmpegKitExtended')
```

If the build output differs in executable behavior, stop and investigate instead of claiming documentation-only closure.

## G3.7 Final generated-document audit

Before closeout, answer all of these from generated output:

1. Does `NativeFFmpegKitExtendedSpec` show actual callable methods/properties?
2. Is `keyof Spec` absent from the public generated page?
3. Can a consumer read parameter and return types without seeing private `Spec`?
4. Does the public log-event page use self-contained scalar types?
5. Are all Codegen `Spec` own members represented in the public contract?
6. Does compile-time/source parity prevent contract drift?
7. Are all public contract members visible in generated Markdown?
8. Are all three advanced bridge symbols grouped under `Advanced / native bridge`?
9. Do generated docs still contain zero internal observer/queue-helper names?
10. Are static constructors still hidden and session constructor guidance retained?
11. Does `docs:api:check` pass on Windows and WSL?
12. Are generated relative links still valid?
13. Are native/Web runtime exports unchanged?
14. Is the npm package policy unchanged?

If any answer is false or uncertain, do not declare documentation closeout.

## G3.8 Exact final source freeze

Only after all gates and final audit pass:

1. commit the documentation/type-only follow-up with a semantic message;
2. push the exact implementation SHA to `dev-wasm`;
3. record the full 40-character SHA;
4. verify the final tracked diff contains no runtime/native/Flutter/ABI/builder/submodule change;
5. dispatch only the wrapper repository source-snapshot workflow against that exact SHA;
6. download the source artifact through the GitHub connector;
7. verify:
   - GitHub artifact digest;
   - embedded `source.tar.gz.sha256`;
   - actual embedded archive SHA-256;
   - every `SHA256SUMS` entry;
   - `SUBMODULES.txt`;
   - `SYMLINKS.tsv`;
   - `snapshot-metadata.json.snapshot_sha`;
   - `runtimeExecution=false`;
8. record snapshot provenance in the tracker through a later metadata-only commit if needed.

Do not create a native/builders snapshot.

---

# Definition of done

The React Native generated API documentation is fully closed only when:

- [ ] the Codegen `Spec extends TurboModule` remains Codegen-compatible;
- [ ] `NativeFFmpegKitExtendedSpec` is an explicit complete consumer contract rather than a mapped `keyof Spec` alias;
- [ ] the public contract page visibly lists the actual low-level methods/properties and signatures;
- [ ] Codegen `Spec` and the public contract have automated bidirectional signature parity;
- [ ] `NativeFFmpegKitExtended` remains runtime-equivalent and is typed with the stable public contract;
- [ ] the public log event renders consumer-understandable scalar types;
- [ ] the advanced native bridge value/spec/event types share one generated category;
- [ ] documentation tests require real generated method signatures instead of prose name matches;
- [ ] all Codegen own members are represented in generated public contract output;
- [ ] internal observer/queue helper names remain absent from generated docs;
- [ ] facade and queue constructors remain hidden from generated docs;
- [ ] session wrapper constructor guidance remains present;
- [ ] strict TypeDoc generation passes with no new broad exemptions;
- [ ] generated-doc drift passes on Windows and WSL;
- [ ] typecheck/test compilation/Codegen/lint pass;
- [ ] prepare and packed declarations pass;
- [ ] full local Node tests pass under the repository's expected platform skips;
- [ ] no runtime-emitting behavior changes;
- [ ] no Flutter, native, platform-native, ABI, builder, or submodule changes;
- [ ] one exact final wrapper source snapshot is downloaded and fully verified.

If all boxes are satisfied, no additional React Native API documentation remediation plan should be generated. Future work should be triggered only by an actual public API/TSDoc change or a newly demonstrated documentation defect.
