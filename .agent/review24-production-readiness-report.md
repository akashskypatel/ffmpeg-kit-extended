# Local wrapper production-readiness closeout

Date: 2026-09-23

Final wrapper source SHA: `f46d64f782b0a3b6663ac9512c5b90426ab34863`

This report records the Flutter and React Native validation performed against the
frozen native ABI using only the supplied local WSL bundles. It does not publish
native binaries and does not use hosted Flutter or React Native validation.

## Source and artifact authority

- The `libs/libffmpegkit` submodule is on `dev` at `b74da2c5d1e294b87d15d73a6687393729e932b3`, matching `origin/dev` after a fast-forward. Its tree is equivalent to the frozen native handoff `625c3452ee3c93fb5d701bb6546726940b88d014`; no native source was changed.
- The local bundles report FFmpegKit `0.11.2` and have these SHA-256 values:
  - Wasm: `49096fe9145e8d5830a2e9e07b16047819eee1f3b3dfb268dc072fd7b6e239ce`
  - Windows: `e7acb728101708402f7ea5d60abd973d624cf3a1598ba998673f7a6275499c2`
  - Linux: `cbe56b1749f028ed107d35bc96800c1635a674366badff86a85c69290b279363`
- Flutter and React Native configuration points to the WSL-local bundle paths. Local-only mode rejects missing overrides and HTTP(S) overrides, preventing fallback to a historical release.
- No remote artifact was downloaded, no native binary was published, and the ManyLinux builder checkout was not modified.

## Flutter

- FFI bindings were regenerated after the native handoff with analytics disabled; both `ffigen` commands exited `0`. The known non-fatal `Unable to parse Macros` warning remained.
- `dart --disable-analytics analyze` and Flutter analysis passed with no issues.
- `FFMPEG_KIT_EXTENDED_LOCAL_ONLY=true flutter test --no-pub --exclude-tags native` passed **172/172**.
- Local Wasm release build and headless browser smoke passed with initialization, FFmpeg, FFprobe, media-information, log, and final-pass markers; assets were served from the local package path with cross-origin isolation and no page or console errors.
- `flutter build windows --release` passed using the local Windows bundle.

## React Native

- Resolver tests cover fail-closed default/remote rejection and explicit local-path acceptance.
- `npm run check` passed **157/157** Node tests; typecheck and lint passed, with one pre-existing unnecessary-escape warning.
- Package type consumers, Web consumers, and `npm pack --dry-run` passed using an isolated temporary npm cache, which was removed afterward.
- The Web bridge now obtains the instantiated Wasm function table and installs the ffigen heap helpers plus a slot-recycling structured callback registry. Dedicated callback-runtime and loader tests passed **5/5**.
- The complete local Web smoke suite passed: initialization, repeated initialization, FFmpeg, FFprobe, media information, FFplay, pause/resume/stop, and the final WebAssembly smoke assertion.
- The local Windows build passed through code generation and MSBuild, producing `FFmpegKitExtended.dll` and the example executable.

## Scope and remaining platform limits

The locally executable Flutter and React Native gates are complete. Android,
Apple, and native Linux commands were not run on this Windows host because the
matching local artifacts were not supplied and remote retrieval/hosted wrapper
CI is prohibited for this handoff. No blocker requiring native ABI changes was
found; this is an environment-scope limitation only.

The requested source-snapshot workflow completed successfully at the final
wrapper SHA: run [35931116466](https://github.com/akashskypatel/ffmpeg-kit-extended/actions/runs/35931116466), source artifact
`review24-wrapper-source-35931116466` (artifact ID `10781008469`),
[download link](https://api.github.com/repos/akashskypatel/ffmpeg-kit-extended/actions/artifacts/10781008469/zip).
