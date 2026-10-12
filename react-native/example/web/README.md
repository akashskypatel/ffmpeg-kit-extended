# React Native Web Example

This is a browser-only React DOM application mounted by the Vite entry in `main.tsx`. It is separate from the shared React Native example in `../src/ExampleApp.tsx` and does not change native or Flutter screens. MUI 7 supplies the Material controls and icons; Emotion is its styling runtime. The five panels share one session/log owner so switching tabs does not unmount FFplay or clear its output.

## Run locally

Run from `react-native/example` with the local Web runtime already staged under `public/ffmpeg-kit-extended/wasm`:

```powershell
node .\node_modules\vite\bin\vite.js --config web/vite.config.js --host 127.0.0.1 --port 4175
```

The regular `web` and `web:build` scripts call `prepare-web`; use them only when runtime staging is intended. The Vite config supplies `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`, which the threaded Wasm runtime needs for browser isolation.

For a Web-only type check from the same directory:

```powershell
node .\node_modules\typescript\bin\tsc --noEmit --target ES2020 --module ESNext --moduleResolution Bundler --jsx react-jsx --strict --skipLibCheck --esModuleInterop --allowSyntheticDefaultImports --types react .\web\App.tsx .\web\theme.ts
```

For a production bundle without writing generated files into the repository, choose a temporary output directory:

```powershell
node .\node_modules\vite\bin\vite.js build --config web/vite.config.js --outDir "$env:TEMP\rn-web-parity-build" --emptyOutDir
```

## Web action map

| Panel or control | Browser behavior |
| --- | --- |
| Initialize / Retry | Calls `FFmpegKitExtended.initialize()`, reads the runtime version and available encoders/muxers, and reports failures for retry. |
| Log level | Calls the public `FFmpegKitExtended.setLogLevel()` API. |
| System information | Reads public version, architecture, package, bundle, build, library, codec, muxer, demuxer, filter and protocol metadata. Basic info includes browser and origin. |
| Clear logs | Clears the displayed and queued log text. It does not cancel active sessions. |
| FFmpeg: Gen Video / Gen Audio / Download MP4 / Download WAV | Runs local lavfi commands through `FFmpegKit` to create an eight-second MP4 or WAV in the browser Wasm filesystem. Download buttons appear only after successful generation and copy the virtual file into a user-triggered browser download. |
| FFmpeg: Async Version / Sync Version / Help / Run FFmpeg | Runs `FFmpegKit` sessions with log callbacks. “Sync” awaits the returned Web Promise and does not block the browser event loop. Help runs `-h`; the command field defaults to `-nostdin -version`. |
| Stream panel | Stream recording is unsupported in Web/Wasm builds, including RTMP/RTMPE. The URL field and Record Stream action are disabled, and no MKV download is offered. Use a supported native build for stream I/O. |
| FFprobe: Pick File / Get Media Info | Copies the selected browser file into the existing Wasm module's `/tmp/` filesystem. Media Info probes that file, or generates the local test video when no file is selected. The selected file is shared with Transcode and FFplay. |
| FFprobe: Async Version / Sync Version / Run FFprobe | Runs `FFprobeKit` sessions with log callbacks; “Sync” awaits the Web Promise. The custom command defaults to `-version`. |
| FFplay: Run FFplay / Play Video / Play Audio / Play Imported File | Creates a real `FFplayKit` session and renders through the public `FFplayView` canvas. Generated media and the shared imported file are available to the quick actions. |
| FFplay transport | Pause, resume, stop, seek, position and volume use the live `FFplaySession` APIs. The canvas remains mounted when another tab is selected. Fullscreen is enabled only when the browser exposes the containing element's Fullscreen API. |
| Transcode: Pick Video File / Transcode to AVI / Download AVI | Uses the selected media file or generates the example MP4, then runs FFmpeg to `/tmp/ffmpeg-kit-web-output.avi`. Progress comes from statistics callbacks; Download AVI appears only after successful completion. |

Media-generation and transcode actions are disabled when the initialized bundle does not report the required encoder and muxer. Enabled buttons still show the real runtime return code and logs; a command error is not reported as success.

Imported media and generated outputs live in the Wasm module's temporary in-memory filesystem. They disappear when the page/runtime is reloaded. The package exposes the synchronous, browser-only byte API from `ffmpeg-kit-extended/web-files`; call `FFmpegKitExtended.initialize()` first and use absolute flat paths directly under `/tmp/`. Browser `File` selection and Blob downloads remain in the example UI.

## Manual local review

Local review against the resolver-staged full/GPL Wasm bundle generated and downloaded MP4 and WAV output. The 98,295-byte MP4 download had SHA-256 `85847A01A924A4090759B08CE1B7E80E3FEA6B07FE182E8437015C3856959C29`, and the 705,678-byte WAV had SHA-256 `B4A87BF5C82A0435A230545D7FF1392BC0A7119A534E5FBFBDEFFE4E696B7A21`; browser downloads of both matched their Wasm bytes exactly. Importing the MP4 into MEMFS preserved the same byte count and hash. FFprobe read its 8-second, 512 × 512 video stream. Re-selecting the same file created a fresh virtual path and removed the prior path after its playback job completed. Imported FFplay completed with return code 0, and pause, resume and stop controls were exercised.

The default-thread transcode first triggered `Cannot set property HEAPU8 ... which has only a getter` during a Wasm memory-view update. The demo now limits its decoder and encoder to one thread; the imported MP4 then transcoded successfully. FFprobe read the resulting AVI as an eight-second, 512 × 512 MPEG-4 video. The 99,032-byte AVI download matched the Wasm file exactly with SHA-256 `3A2E913A040B06E085ED76C101818D718A525D5D5CFE5B64BC5421A7F7D52D1E`. This Wasm build does not support network stream recording, including RTMP/RTMPE; an earlier local loopback attempt returned `-53` (`Socket not connected`). Stream recording and MKV download are therefore unavailable in the Web example.

Local gates run: package build, package typecheck, test compilation, 8 focused Web file API tests, the Web example TypeScript check, and a Vite production build to a temporary directory. No remote CI, workflow, external stream, Flutter/native build, or smoke script was run.

## Known external smoke-script follow-up

`react-native/scripts/web-smoke.js` is outside this Web-only change boundary and was not run or edited. It assumes the Initialize, Run FFmpeg, Run FFprobe, Run Media Info, Run FFplay, Pause, Resume and Stop buttons are all visible together. The tabbed UI keeps the existing `data-testid="status"` and `data-testid="output"`, but future smoke automation needs to select the corresponding tab before locating its action. Do not add hidden duplicate controls to work around that navigation requirement.
