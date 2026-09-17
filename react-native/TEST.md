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

## Web checks

Build the package and browser example with:

```bash
npm run check
npm run prepare
npm pack --dry-run
npm --prefix example install
npm --prefix example run prepare-web
npm --prefix example run web:build
```

For a real Wasm smoke test, run `npm --prefix example run prepare-web`; the resolver downloads and stages the configured published bundle, or uses an explicit local/remote override when provided. Start the example with `npm --prefix example run web` and use a headless Chromium session. The browser must report `crossOriginIsolated === true`; the smoke flow initializes once, repeats initialization, runs FFmpeg and FFprobe, exercises FFplay controls, and verifies that no console errors are emitted.

The Wasm runtime is intentionally not included in the npm package. `prepare-web` stages it from the configured release artifact or local override, so package checks do not silently bundle a large binary.
