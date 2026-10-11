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
| FFmpeg: Gen Video / Gen Audio | Runs local lavfi commands through `FFmpegKit` to create an eight-second MP4 or WAV in the browser Wasm filesystem. Buttons are gated by the configured bundle's encoder/muxer list. |
| FFmpeg: Async Version / Sync Version / Help / Run FFmpeg | Runs `FFmpegKit` sessions with log callbacks. “Sync” awaits the returned Web Promise and does not block the browser event loop. Help runs `-h`; the command field defaults to `-nostdin -version`. |
| Stream: Record Stream | Runs an HTTP(S) input through `FFmpegKit` with stream-copy output to `/tmp/ffmpeg-kit-web-stream.mkv`. Active sessions and progress are tracked and can be cancelled. Browser CORS, server response headers and the configured FFmpeg protocols may prevent remote input. The output is a virtual Wasm path, not an OS file. |
| Stream: Refresh running sessions | Re-reads tracked session state and updates the active-session list. No remote stream was started during the manual review. |
| FFprobe: Get Media Info | Calls `FFprobeKit.getMediaInformation()` on the generated local test video and displays the returned metadata. |
| FFprobe: Async Version / Sync Version / Run FFprobe | Runs `FFprobeKit` sessions with log callbacks; “Sync” awaits the Web Promise. The custom command defaults to `-version`. |
| FFprobe: Pick File / Transcode: Pick Video File | Disabled. A browser `File` object is not exposed to the Wasm filesystem through this public SDK. |
| FFplay: Run FFplay / Play Video / Play Audio | Creates a real `FFplayKit` session and renders through the public `FFplayView` canvas. Generated media is used by the quick actions. |
| FFplay transport | Pause, resume, stop, seek, position and volume use the live `FFplaySession` APIs. The canvas remains mounted when another tab is selected. Fullscreen is enabled only when the browser exposes the containing element's Fullscreen API. |
| Transcode MP4 → AVI | Runs an FFmpeg session from the generated MP4 to `/tmp/ffmpeg-kit-web-output.avi` and displays FFmpeg statistics callbacks. The public Web SDK does not expose downloading that virtual file. |

Media-generation and transcode actions are disabled when the initialized bundle does not report the required encoder and muxer. Enabled buttons still show the real runtime return code and logs; a command error is not reported as success.

## Manual local review

The five tabs were visually inspected at a 2048 × 1113 desktop viewport. The responsive layout was inspected at 390 × 844, including the compact icon tabs, the content/log split and the fitted toolbar; the toolbar also fits at 320 px. The runtime review generated MP4 and WAV media, read MP4 metadata, ran FFmpeg and FFprobe version sessions, played the generated video with the real canvas, exercised pause/resume/seek/stop, mute and tab persistence, and completed MP4-to-AVI transcode. Stream recording was not attempted because it would make an external network request and depends on server CORS/protocol support.

No test suite, remote CI, Flutter/native build, runtime fetch or external smoke script was run for this Web UI change.

## Known external smoke-script follow-up

`react-native/scripts/web-smoke.js` is outside this Web-only change boundary and was not run or edited. It assumes the Initialize, Run FFmpeg, Run FFprobe, Run Media Info, Run FFplay, Pause, Resume and Stop buttons are all visible together. The tabbed UI keeps the existing `data-testid="status"` and `data-testid="output"`, but future smoke automation needs to select the corresponding tab before locating its action. Do not add hidden duplicate controls to work around that navigation requirement.
