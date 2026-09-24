## Development checks

Run the package-level validation suite from the repository root:

```bash
npm run check
```

The checks are also available independently:

```bash
npm run typecheck
npm run lint
npm test
npm run test:unit
npm run test:config
```

`npm test` compiles the native-independent TypeScript modules into the ignored `.test-dist` directory and runs them with Node's built-in test runner. The suite covers command argument parsing/serialization, media-information models, session queue behavior, return-code helpers, FFmpegKit bundle configuration resolution, and the consumer-owned Codegen lifecycle contract. Native FFmpeg/FFprobe/FFplay execution is intentionally left to the example-app integration tests because unit tests cannot accurately validate the platform binaries or TurboModule bridge.

## React Native Web checks

The commands below are the local authority when the native ABI is unpublished
or has changed locally. Do not use hosted workflows for this validation: those
runners cannot fetch the local ABI archive and must not substitute a remotely
staged binary.

Build the package and browser example with:

```bash
npm run check
npm run prepare
npm run test:pack-types
npm run test:pack-web
npm pack --dry-run
npm --prefix example install
npm --prefix example run web:build
npm run test:web
```

Run `npm run test:pack-types` after `npm run prepare`. It packs the generated
package and verifies that TypeScript resolves declarations from the tarball for
the supported `react-native` and `browser` plus `react-native` conditions. The
local packed-consumer check is required before the browser smoke test.

The Web start and build scripts invoke the package-owned resolver automatically. `npm run test:web` also prepares the example before launching its headless Chromium smoke test, so no binary path or separately staged artifact is required. The resolver downloads and stages the configured published bundle, or uses an explicit local/remote override when provided. The browser must report `crossOriginIsolated === true`; the smoke flow initializes once, repeats initialization, runs FFmpeg and FFprobe, exercises FFplay controls, and verifies that no console errors are emitted.

For unpublished local ABI validation, set the example's Web override to the
local builder archive before running the commands above:

```text
\\wsl.localhost\ManyLinux\home\vscode\ffmpeg-kit-builders\prebuilt\wasm-wasm32\releases\bundle-base-wasm-wasm32-static-lgpl.zip
```

The Web callback registry retains a stable Wasm table slot after logical
unregistration. Native delivery is disabled immediately, but the slot is not
recycled while the module remains alive, so an already queued native callback
cannot call a newly installed callback. The native bridge likewise reuses one
active per-module state and only retains a state during module destruction for
callbacks already in flight. The focused lifetime and delayed-callback checks
are:

```bash
npm run test:compile
node --test tests/wasm-callback-runtime.test.js tests/wasm-backend-memory.test.js tests/native-bridge-lifetime.test.js
```

`npm run test:web` is the real browser/runtime check. The callback and bridge
tests are deterministic lifecycle checks; they do not replace the browser
smoke test or the native Windows build.

Initialization coverage includes module-factory rejection, Wasm instantiation rejection, retry after a failed attempt, and concurrent initialization deduplication.

## Process-global native log registration ownership

FFmpegKit exposes one process-global structured log callback registration. A
React Native module keeps its callback user-data storage alive long enough for
already accepted native work, and the most recent successful module
installation owns the process-global registration.

Uninstalling or destroying a stale non-owner deactivates only that module's
local bridge state; it does not call the global native setter and cannot clear
a newer module's registration. Uninstalling the current owner clears the
native registration. There is no automatic restoration of a previous module's
registration, and unregistration is not queue draining.

The executable ownership fixture covers replacement, repeated stale teardown,
current-owner clearing, failed install/disable preservation, and concurrent
replacement versus stale teardown:

```bash
g++.exe -std=c++20 -pthread -Wall -Wextra -Werror -I react-native/cpp react-native/tests/native/log_bridge_registration_coordinator_test.cpp -o .tmp-r26/log_bridge_registration_coordinator_test.exe
.tmp-r26\log_bridge_registration_coordinator_test.exe
```

The fixture is a deterministic native ownership check. It complements the
source-contract test and the real Windows Release build; it is not a substitute
for either package/browser runtime validation.

## Review 23 callback transport evidence

Review 23 uses an additive ABI-v2 event path. The direct path carries
`sessionId`, `sequence`, `level`, and `message`, avoids steady-state indexed
history reads, and reconciles only a bounded terminal gap. The native history
getters remain the public inspection and explicit v1 compatibility path.

The local ownership and session fixtures are the counter oracle when the
unpublished native ABI is under test:

```bash
node --test tests/wasm-backend-memory.test.js tests/wasm-session-ownership.test.js tests/codegen-lifecycle.test.js
```

They assert completion with no optional consumers, direct delivery with zero
steady-state history reads, one terminal count read, bounded gap recovery,
duplicate suppression, ordering, redirection authority, and owned-payload
release. Wrapper fixtures do not instrument native allocation/free counters;
the native/Wasm ownership tests prove balance and free-once behavior instead.

Run `npm run test:web` locally for the browser gate. Hosted workflow build or
compile output is not browser-runtime evidence, and unpublished native ABI
changes must use locally built runtimes rather than a workflow artifact.

The Wasm runtime is intentionally not included in the npm package. The Web build hook stages it from the configured published release or local override, so package checks do not silently bundle a large binary.

The complete local gate covers the same package checks plus the Windows ZIP
staging path:

- `npm run check`
- `npm run prepare`
- `npm run test:pack-types`
- `npm run test:pack-web`
- `npm pack --dry-run`
- `npm --prefix example run web:build`
- `npm run test:web`
- Windows nested-ZIP staging through `prepare-web.js`
