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

The standalone `React Native Web checks` workflow in
`.github/workflows/react_native_web_ci.yaml` is the authoritative React Native
Web/WASM CI workflow. It is self-contained and does not depend on Flutter
validation.

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
the supported `react-native` and `browser` plus `react-native` conditions. Both
React Native Web workflows enforce this packed-consumer check.

The Web start and build scripts invoke the package-owned resolver automatically. `npm run test:web` also prepares the example before launching its headless Chromium smoke test, so no binary path or separately staged artifact is required. The resolver downloads and stages the configured published bundle, or uses an explicit local/remote override when provided. The browser must report `crossOriginIsolated === true`; the smoke flow initializes once, repeats initialization, runs FFmpeg and FFprobe, exercises FFplay controls, and verifies that no console errors are emitted.

Initialization coverage includes module-factory rejection, Wasm instantiation rejection, retry after a failed attempt, and concurrent initialization deduplication.

The Wasm runtime is intentionally not included in the npm package. The Web build hook stages it from the configured published release or local override, so package checks do not silently bundle a large binary.

The authoritative workflow covers the same React Native gates plus the
Windows ZIP staging path:

- `npm run check`
- `npm run prepare`
- `npm run test:pack-types`
- `npm run test:pack-web`
- `npm pack --dry-run`
- `npm --prefix example run web:build`
- `npm run test:web`
- Windows nested-ZIP staging through `prepare-web.js`
