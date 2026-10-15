# React Native Web Example

This is a browser-only React DOM application mounted by the Vite entry in `main.tsx`. It is separate from the shared React Native example in `../src/ExampleApp.tsx` and does not change native or Flutter screens. MUI 7 supplies the Material controls and icons; Emotion is its styling runtime. The five panels share one session/log owner so switching tabs does not unmount FFplay or clear its output.

## Run locally

Run from `react-native/example` with the local Web runtime already staged under `public/ffmpeg-kit-extended/wasm`:

```powershell
node .\node_modules\vite\bin\vite.js --config web/vite.config.js --host 127.0.0.1 --port 4175
```

The regular `web` and `web:build` scripts call `prepare-web`; use them only when runtime staging is intended. The Vite config supplies `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`, which the threaded Wasm runtime needs for browser isolation.

`prepare-web` stages the runtime pair and all four bridge support modules: `ffmpegkit_bridge.mjs`, `ffmpegkit_loader.mjs`, `ffmpegkit_callback_runtime.mjs`, and `ffmpegkit_heap_runtime.mjs`. Its tests check the copied source bytes and local relative-import closure, including a missing-module failure. For offline validation, either start Vite directly after staging a local runtime as above, or set `web`/`wasm` to an explicit local directory or ZIP and set `FFMPEG_KIT_EXTENDED_LOCAL_ONLY=true` in the staging process. Local-only mode rejects default release resolution and HTTP(S) overrides. Direct Vite does not invoke the resolver or download a runtime. See [React Native Web setup](../../README.md#react-native-web-setup) for the override format.

For a Web-only type check from the same directory:

```powershell
node .\node_modules\typescript\bin\tsc --noEmit --target ES2020 --module ESNext --moduleResolution Bundler --jsx react-jsx --strict --skipLibCheck --esModuleInterop --allowSyntheticDefaultImports --types react .\web\App.tsx .\web\theme.ts
```

For a production bundle without writing generated files into the repository, choose a temporary output directory:

```powershell
node .\node_modules\vite\bin\vite.js build --config web/vite.config.js --outDir "$env:TEMP\rn-web-parity-build" --emptyOutDir
```

## Runtime integration

The browser package loads the private bridge modules from `public/ffmpeg-kit-extended/wasm/`: the generated `ffmpegkit.mjs` and `ffmpegkit.wasm` pair plus `ffmpegkit_bridge.mjs`, `ffmpegkit_loader.mjs`, `ffmpegkit_callback_runtime.mjs`, and `ffmpegkit_heap_runtime.mjs`. The bridge requires a secure, cross-origin-isolated page (`crossOriginIsolated` and `SharedArrayBuffer`); this Vite server supplies COOP `same-origin` and COEP `require-corp`.

For reproducible offline staging, configure the local small video/GPL Wasm ZIP in `ffmpeg-kit-extended.config.json`, then run from the repository root:

```bash
bash react-native/clean.sh
npm --prefix react-native run prepare
FFMPEG_KIT_EXTENDED_LOCAL_ONLY=1 npm --prefix react-native/example run prepare-web
```

The local-only resolver accepts `1` or `true` and rejects default or remote artifact resolution. After staging, compare both generated runtime hashes with the pinned values in [the RN bridge guide](../../doc/web-native-bridge.md). Media input reaches the native runtime through asynchronous FFmpeg/FFprobe execution. See the [public API support table and copyable streaming commands](../../doc/web-streaming.md) and [React Native Web setup](../../README.md#react-native-web-setup).

## Web action map

| Panel or control | Browser behavior |
| --- | --- |
| Initialize / Retry | Calls `FFmpegKitExtended.initialize()`, reads the runtime version and available encoders/muxers, and reports failures for retry. |
| Log level | Calls the public `FFmpegKitExtended.setLogLevel()` API. |
| System information | Reads public version, architecture, package, bundle, build, library, codec, muxer, demuxer, filter and protocol metadata. Basic info includes browser and origin. |
| Clear logs | Clears the displayed and queued log text. It does not cancel active sessions. |
| FFmpeg: Gen Video / Gen Audio / Download MP4 / Download WAV | Runs local lavfi commands through `FFmpegKit` to create an eight-second MP4 or WAV in the browser Wasm filesystem. Download buttons appear only after successful generation and copy the virtual file into a user-triggered browser download. |
| FFmpeg: Async Version / Sync Version / Help / Run FFmpeg | Runs `FFmpegKit` sessions with log callbacks. “Sync” awaits the returned Web Promise and does not block the browser event loop. Help runs `-h`; the command field defaults to `-nostdin -version`. |
| Stream panel | Remote URL (Web) accepts direct `http://` and `https://` media. Probe runs `FFprobeKit` asynchronously, Play runs `FFplayKit` into the FFplay surface, Record 15 s writes a bounded MKV to `/tmp` in browser memory, and Download Recording saves it. Stop cancels the running operation once. RTMP, RTSP, file and chained schemes are rejected, and the panel is enabled only when the runtime reports ABI 0.11.2. Indirect network inputs such as a local playlist with remote segments fail with EPERM. |
| FFprobe: Pick File / Get Media Info | Copies the selected browser file into the existing Wasm module's `/tmp/` filesystem. Media Info probes that file, or generates the local test video when no file is selected. The selected file is shared with Transcode and FFplay. |
| FFprobe: Async Version / Sync Version / Run FFprobe | Runs `FFprobeKit` sessions with log callbacks; “Sync” awaits the Web Promise. The custom command defaults to `-version`. |
| FFplay: Run FFplay / Play Video / Play Audio / Play Imported File | Creates a real `FFplayKit` session and renders through the public `FFplayView` canvas. Generated media and the shared imported file are available to the quick actions. |
| FFplay transport | Pause, resume, stop, seek, position and volume use the live `FFplaySession` APIs. The canvas remains mounted when another tab is selected. Fullscreen is enabled only when the browser exposes the containing element's Fullscreen API. |
| Transcode: Pick Video File / Transcode to AVI / Download AVI | Uses the selected media file or generates the example MP4, then runs FFmpeg to `/tmp/ffmpeg-kit-web-output.avi`. For a known input duration, statistics time is converted from milliseconds to a monotonic percentage capped at 99% until FFmpeg succeeds and the output exists. Missing or invalid duration leaves progress indeterminate. Download AVI appears only after successful completion. |

Media-generation and transcode actions are disabled when the initialized bundle does not report the required encoder and muxer. Enabled buttons still show the real runtime return code and logs; a command error is not reported as success.

Imported media and generated outputs live in the Wasm module's temporary in-memory filesystem. They disappear when the page/runtime is reloaded. The package exposes the synchronous, browser-only byte API from `ffmpeg-kit-extended/web-files`; call `FFmpegKitExtended.initialize()` first and use absolute flat paths directly under `/tmp/`. Browser `File` selection and Blob downloads remain in the example UI.

`FFmpegKitWebFiles.writeFile(path, bytes)` copies a `Uint8Array` into the initialized runtime; `readFile(path)` returns bytes, and `exists(path)` / `deleteFile(path)` query or remove the virtual file. Imports, Emscripten MEMFS storage, and Blob downloads can each require additional browser memory. The API is browser-local and synchronous; it does not stream bytes to or from a server.

After initialization the example checks the exported filesystem surface with `exists()` and does not create a probe file. If `FS` or a required method is missing, the page shows a runtime compatibility message and disables file import, media generation, metadata reads, imported playback, downloads, and file transcoding. Version and introspection actions stay available when the runtime supports them.

When a new file replaces an imported selection, the previous virtual path is retained while any tracked FFmpeg, FFprobe, or FFplay job is active. An imported transcode also takes an outer reservation before its duration probe and holds it until the FFmpeg session reaches terminal settlement; the nested probe reservation cannot create a gap before FFmpeg registration. Probe failure, session startup failure, and cancellation release the reservation through the same `finally` path. The previous file is removed after the last reservation/job settles and a safe cleanup pass runs. This conservative rule can keep a large file in memory longer than its own job; reloading the page clears the temporary filesystem.

## Local remediation evidence (2026-10-11)

The browser smoke used the already cached full/static-GPL Wasm archive `bundle-full-wasm-wasm32-static-gpl.zip` (archive SHA-256 `00DE58BD255848794A31CE00E53E9DD31AF66EAD6D9CE5F95C16182AE579D25A`). Its extracted runtime matched the locally staged pair: `ffmpegkit.mjs` SHA-256 `DB4A83B52C6EEF63CE9E5B44281EEA140040F22B829CA6A0D1647AD378FBA358`; `ffmpegkit.wasm` SHA-256 `A293E1909F3C862C6FB6889FF7A12638F4364EAA00CD0AFDF2AE9C66ACF8B0A4`. The archive name identifies version 0.11.2 and the full/static-GPL Wasm target, but it does not contain a builder commit or source manifest, so the builder source revision is not independently confirmed. Direct Vite served only the local staged files at `127.0.0.1:4175`; Chrome 155.0.8059.40 reported `crossOriginIsolated`, and no external browser requests were observed.

Before the bridge fix, a one-frame 8192 × 8192 YUV420 raw-video command reproduced `Cannot set property HEAPU8 ... which has only a getter` during Emscripten's memory-view refresh. After the fix, the same command exited 0 and grew shared Wasm memory from 67,108,864 bytes (64 MiB) to 251,789,312 bytes (about 240 MiB). `HEAPU8`, `HEAPU32`, and `HEAPF32` remained writable data properties pointing at the new memory buffer. An imported 98,295-byte MP4 (SHA-256 `85847A01A924A4090759B08CE1B7E80E3FEA6B07FE182E8437015C3856959C29`) then transcoded with the runtime's default thread settings and no manual `-threads 1` option. FFprobe read the resulting 109,032-byte AVI (SHA-256 `f47e6adc090b94f9218909318a4e4b7a1bbf46a078258db5ace7b52489289d83`) as an eight-second MPEG-4 video. After actual memory growth, FFprobe read the generated MP4 and FFplay rendered it; pause, resume, and stop worked. A generated MP4 download matched its Wasm filesystem bytes exactly (98,295 bytes, SHA-256 `85847A01A924A4090759B08CE1B7E80E3FEA6B07FE182E8437015C3856959C29`). A separate 160,802-byte AVI (SHA-256 `52d5072b2ddbb2159096120a72ae9eb104c3edbf6309c5e31c473d5be85d6aef`) was identified by FFprobe as 12-second 512 × 512 MPEG-4, downloaded byte-for-byte, and played in FFplay with pause, resume, and stop. The browser also preserved the `00 80 FF` binary pattern through file import, Wasm readback, and download.

A separate 24-second, 1920 × 1080 input produced FFprobe duration `24.000000`. During AVI transcoding the observed active progress samples reached 33% and 71%; the bar remained below 100% until the successful output existed, then completed at 100%. The output was 2,082,482 bytes (SHA-256 `2c5063cf0b391c0bec030069608638667b5f38e8d960c4673df5331dcd09682e`). An invalid three-byte input failed with return code `-1094995529`, cleared the stale transcode state, and exposed no AVI download. Local browser replacement checks for custom FFmpeg, active custom FFprobe, and imported FFplay retained the retired import until tracked work settled, then removed it while keeping the current selection. A missing-FS browser run displayed the compatibility message, disabled file actions across FFprobe/FFplay/Transcode, and kept the async version action available and successful. That negative run temporarily altered only the ignored staged module; its original SHA-256 was restored exactly afterward.

These historical checks used the older artifact described above. Current direct HTTP(S)/HLS input and bounded MKV recording require the pinned local runtime in the bridge guide. Stop keeps controls busy until cancellation completes. The ABI check rejects different versions; it cannot distinguish older builds with the same `0.11.2` ABI, so verify the staged file hashes too. Direct RTMP/RTMPE remains unsupported.

## Known external smoke-script follow-up

`react-native/scripts/web-smoke.js` is outside this Web-only change boundary and was not run or edited. It assumes the Initialize, Run FFmpeg, Run FFprobe, Run Media Info, Run FFplay, Pause, Resume and Stop buttons are all visible together. The tabbed UI keeps the existing `data-testid="status"` and `data-testid="output"`, but future smoke automation needs to select the corresponding tab before locating its action. Do not add hidden duplicate controls to work around that navigation requirement.
