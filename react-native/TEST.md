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