# React Native API Documentation Final Follow-up Audit

Date: 2026-10-03  
Repository: `akashskypatel/ffmpeg-kit-extended`  
Branch represented by snapshot: `dev-wasm`  
Review type: frozen-source documentation/type-surface audit; substantive findings only

## 1. Authority and provenance

This audit uses the exact source artifact supplied for the completed consumer-facing API follow-up.

Verified authority:

- implementation/source SHA: `a5d11102063710582895ee2425289bd06bb5bb80`
- later tracker metadata commit: `32104e8` (not part of the snapshotted implementation source)
- workflow run: `37144478826`
- source artifact: `react-native-consumer-api-source-snapshot-37144478826`
- artifact ID: `11282041436`
- GitHub artifact SHA-256: `e3bc6ebf982a2fe603d49e02b64f118d6ea87ebc901150a4ea344d57b1124d8c`
- embedded `source.tar.gz` SHA-256: `35cb1e88bbbf8ab13d27709083898d90aa5dfa88a9bd54f0b44a7e5eb7876062`
- snapshot metadata SHA: `a5d11102063710582895ee2425289bd06bb5bb80`
- manifest entries: `1138/1138` verified
- symlinks: `0`
- `runtimeExecution=false`
- frozen recursive native submodule: `libs/libffmpegkit` at `b74da2c5d1e294b87d15d73a6687393729e932b3`

The user-reported archive hash `35cb1e88...6062` is the embedded source archive checksum and independently matches the downloaded artifact contents.

No native ABI, Flutter, platform-native, builder, or submodule source was re-reviewed or modified for this audit.

## 2. Overall disposition

The completed follow-up materially closes three of the four previously identified consumer-surface gaps and preserves the accepted TypeDoc/drift infrastructure.

Status:

| Area | Disposition |
| --- | --- |
| Internal observer type leakage | Closed |
| Internal queue-helper type leakage | Closed |
| Facade/queue constructor presentation | Closed |
| Session-wrapper constructor guidance | Closed |
| Generated-link integrity | Closed — 568 relative Markdown links checked, 0 broken |
| Strict TypeDoc/drift tooling | Closed |
| Advanced native bridge discoverability | **Not closed — 1 substantive documentation finding remains** |
| Runtime/native/Flutter behavior | Frozen; no finding |

The remaining issue does not require runtime, native, platform-native, Flutter, ABI, builder, or submodule changes.

## 3. Verification of completed follow-up goals

### 3.1 Internal observer type no longer leaks from `Session`

`react-native/src/session.ts` no longer declares:

```ts
export abstract class Session implements RestoredSessionObservationTarget
```

The class remains structurally compatible with the observer implementation without publishing that implementation relationship to TypeDoc.

Generated `doc/api/classes/Session.md` contains no `RestoredSessionObservationTarget` reference.

Disposition: **closed**.

### 3.2 Queue-manager public generated signatures are consumer-facing

`SessionQueueManager` now generates:

```text
activeSessions: Session[]
cancelCurrent(): void | Promise<void>
clearQueue(): void | Promise<void>
cancelAll(): void | Promise<void>
```

The generated reference contains zero occurrences of:

- `CancellableSession`
- `MaybePromise`

The queue-internal aliases and methods remain implementation details and are excluded from TypeDoc.

Disposition: **closed for the generated consumer reference**.

### 3.3 Constructor presentation is corrected

Generated pages for these static/process facades no longer contain a Constructors section:

- `FFmpegKit`
- `FFprobeKit`
- `FFplayKit`
- `FFmpegKitConfig`
- `FFmpegKitExtended`
- `SessionQueueManager`

The runtime constructors were not removed; this is documentation-only presentation through `@hideconstructor`.

The concrete session constructors now explain that they wrap an existing valid native session identity and that arbitrary IDs do not create a native session:

- `FFmpegSession`
- `FFprobeSession`
- `MediaInformationSession`
- `FFplaySession`

The timeout-bearing session constructors also document milliseconds.

Disposition: **closed**.

### 3.4 TypeDoc exemptions are narrowed

`react-native/typedoc.json` now contains only:

```json
"intentionallyNotExported": ["Spec"]
```

The previous exemptions for `RestoredSessionObservationTarget`, `CancellableSession`, and `MaybePromise` are gone.

Strict validation and warning-as-error behavior remain enabled.

Disposition: **closed**.

### 3.5 Generated reference integrity

The current generated tree contains **46 Markdown pages**.

A static relative-link audit over every Markdown file found:

```text
568 relative links checked
0 missing targets
```

The existing generator/drift design remains appropriate:

- one native public entry point;
- committed Markdown;
- package-local TypeDoc execution;
- strict validation;
- deterministic temporary-directory regeneration/diff;
- no generated-doc mutation during `docs:api:check`.

No redesign is recommended.

## 4. Remaining finding — advanced native bridge contract is still opaque

Severity: **Medium**

Affected source/docs:

- `react-native/src/NativeFFmpegKitExtended.ts`
- `react-native/doc/api/type-aliases/NativeFFmpegKitExtendedSpec.md`
- `react-native/doc/api/type-aliases/NativeFFmpegKitExtendedLogEvent.md`
- `react-native/tests/documentation-contract.test.js`
- generated API index/category metadata

### 4.1 Intended contract

The follow-up goal was to make the advanced native-only bridge reference self-contained so a framework/integration author can inspect the actual low-level API without needing the private Codegen `Spec` symbol.

The runtime value page now correctly points to the stable public name:

```text
NativeFFmpegKitExtended: NativeFFmpegKitExtendedSpec
```

That is an improvement over the previous opaque `Spec` variable type.

### 4.2 Actual generated contract page

The public type is currently declared as:

```ts
export type NativeFFmpegKitExtendedSpec = {
  [Key in keyof Spec]: Spec[Key];
};
```

TypeDoc consequently renders the entire public page as:

```text
NativeFFmpegKitExtendedSpec = { [Key in keyof Spec]: Spec[Key] }
```

No Methods section is generated.

No signatures are generated for:

- `initialize()`
- `createFFmpegSession()`
- `createFFmpegSessionFromArguments()`
- `executeSessionAsync()`
- `cancelSession()`
- `getSessionJson()`
- `getSessionState()`
- `releaseSessionHandle()`
- FFplay controls
- configuration methods
- introspection methods
- history/pipe/debug methods
- `onLogEvent`

The page therefore still requires knowledge of the intentionally non-exported/non-generated `Spec` interface to understand the API.

This is not self-contained consumer documentation.

### 4.3 The current regression is a false positive for this requirement

`react-native/tests/documentation-contract.test.js` checks that the generated contract page contains the words:

```text
initialize
createFFmpegSession
getSessionJson
ffplayPause
clearSessions
```

Those words currently occur only in descriptive prose:

```text
Representative methods include `initialize`, `createFFmpegSession`,
`getSessionJson`, `ffplayPause`, and `clearSessions`.
```

The test does **not** prove that TypeDoc generated method entries or signatures.

A page containing only the mapped alias plus those five prose names therefore passes even though the actual method inventory remains invisible.

### 4.4 Consumer log-event page is also not fully self-contained

`NativeFFmpegKitExtendedLogEvent.md` currently renders:

```text
level: Int32
sequence: Double
sessionId: Double
message: string
```

`Int32` and `Double` are React Native Codegen scalar aliases imported from an internal Codegen types module. They have no generated API pages or explanatory links in this reference.

For a deliberately stable consumer-facing documentation type, these fields should render as ordinary JavaScript/TypeScript `number` values while the private Codegen `LogEvent` continues using `Double` and `Int32` exactly as required by React Native Codegen.

### 4.5 Navigation/category quality

`NativeFFmpegKitExtended` correctly appears under `Advanced / native bridge`, but the two new public type aliases currently fall into `Other` in the generated API index.

When the advanced contract is corrected, place these public types in the same category:

- `NativeFFmpegKitExtendedSpec`
- `NativeFFmpegKitExtendedLogEvent`

This is a secondary discoverability correction attached to the substantive self-contained-contract fix; it is not a separate finding.

## 5. Required remediation semantics

The fix must satisfy all of the following:

1. Keep the React Native Codegen declaration named exactly `Spec` and keep its Codegen-compatible structure.
2. Do not make Codegen depend on a documentation interface/type that its parser may not support.
3. Publish `NativeFFmpegKitExtendedSpec` as an explicit type-only object contract whose generated page contains the actual methods/properties and signatures.
4. Preserve exact signature parity between the Codegen `Spec` surface and the public documentation contract with a compile-time or AST/source-contract parity check.
5. Keep `NativeFFmpegKitExtended` runtime behavior unchanged.
6. Prefer `TurboModuleRegistry.getEnforcing<Spec>(...)` for the Codegen-facing generic and use an erased type assertion/annotation to expose the consumer-facing public type if necessary.
7. Render the stable log event with consumer-understandable scalar types (`number`/`string`) while keeping Codegen's `LogEvent` spelling/types intact.
8. Strengthen the generated-doc regression so it verifies generated method sections/signatures, not method names appearing anywhere in prose.
9. Preserve strict TypeDoc validation and the existing drift checker.
10. Do not add another documentation framework or dependency.

## 6. Surfaces that are already closed and must not be reopened

Do not redesign or change:

- TypeDoc `0.28.x` / `typedoc-plugin-markdown` tooling;
- `scripts/check-api-docs.js` regeneration/diff strategy;
- README generated-doc link policy;
- npm `files` policy — the accepted design intentionally keeps committed API Markdown GitHub-hosted rather than placing `doc` in the package tarball;
- internal observer methods;
- queue execution/cancellation behavior;
- session lifecycle behavior;
- public facade runtime constructors;
- Web backend/runtime;
- React Native native bridges;
- Flutter;
- native ABI/runtime `0.11.2`;
- `libs/libffmpegkit`;
- ManyLinux builders.

## 7. Closeout criterion

React Native generated API documentation can be considered closed after the advanced native bridge page itself visibly documents the full supported low-level contract, rather than merely referring to hidden `Spec` through a mapped type.

Required final evidence:

- `NativeFFmpegKitExtendedSpec.md` contains real generated method/property sections and no `keyof Spec` dependency;
- the generated public contract and Codegen `Spec` are automatically kept in signature parity;
- the stable public log-event page uses self-contained consumer scalar types;
- advanced public bridge types are categorized with the bridge value;
- strengthened documentation contract fails on the current `a5d1110...` snapshot and passes after remediation;
- TypeDoc strict generation and drift checks pass on Windows and WSL;
- Codegen lifecycle checks pass;
- packed declarations pass;
- no emitted runtime/native/Flutter/ABI/builder/submodule behavior changes;
- one exact wrapper source snapshot is verified only after the final documentation/type-only change is frozen.
