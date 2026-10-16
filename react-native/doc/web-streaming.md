# Direct Web media URLs

Use the locally staged streaming runtime described in the [Web bridge guide](web-native-bridge.md).
The example's Stream tab accepts direct HTTP(S) media URLs and provides Probe,
Play, Record 15 s, Stop, Probe Recording and Download Recording. Playback uses
the existing FFplay surface and SDL audio. Recordings stay in Wasm memory until
deleted or the page is closed.

| API | Local / Wasm files | Direct HTTP(S) and HLS on Web |
|---|---|---|
| `FFmpegKit.executeAsync` / session `executeAsync` | Supported | Asynchronous input; bounded recording supported |
| `FFprobeKit.executeAsync` / session `executeAsync` | Supported | Asynchronous metadata probe |
| `FFprobeKit.getMediaInformation` | Supported | Asynchronous metadata probe (returns a Promise) |
| `FFplayKit.executeAsync` / session `executeAsync` | Supported | Asynchronous playback on the FFplay surface |
| `FFplayKit.hasVideoStream` | `true` only for a successful video result; failed opens return `false` | Throws `Error`; use async FFprobe |

React Native exposes no synchronous execute path. Keep a session reference
before starting so a Stop button can cancel a pending request:

```ts
import {FFmpegKit, FFplayKit, FFprobeKit} from 'ffmpeg-kit-extended';
import {FFmpegKitWebFiles} from 'ffmpeg-kit-extended/web-files';

const probe = FFprobeKit.createSession(
  '-hide_banner -v error -show_streams -show_format -of json "https://example.com/media.mp4"',
);
await probe.executeAsync();
console.log(probe.getOutput());

const playback = FFplayKit.createSession(
  '-hide_banner -loglevel info -autoexit -i "https://example.com/live/playlist.m3u8"',
);
const playbackDone = playback.executeAsync();
// Keep playback running for at least 30 seconds. A Stop handler can call:
// await playback.cancel();
await playbackDone;

const output = '/tmp/hls-recording.mkv'; // Use a unique path per recording.
const recording = FFmpegKit.createSession(
  '-hide_banner -nostdin -y -t 15 -i "https://example.com/live/playlist.m3u8" ' +
  `-map 0:v:0 -map 0:a:0? -c copy -f matroska "${output}"`,
);
await recording.executeAsync({
  statisticsCallback: (statistics) => console.log(
    `Recorded ${Math.floor(statistics.time / 150)}% ` +
    `(${statistics.size} bytes, ${statistics.time / 1000}s media)`,
  ),
});
if (recording.getReturnCode() !== 0) throw new Error(recording.getOutput());
const bytes = FFmpegKitWebFiles.readFile(output);
// Download the bytes using a Blob URL and an <a download> link, as in the example.
// Reprobe the local path before deleting it:
const reprobe = FFprobeKit.createSession(`-v error -show_format -of json "${output}"`);
await reprobe.executeAsync();
console.log(reprobe.getOutput());
FFmpegKitWebFiles.deleteFile(output);
```

Cancellation is a request. Keep controls busy until the execution settles, and
track whether the user requested cancellation separately from the native return
code: cancellation can return zero. Completion runs once. Read and delete output
only after the writer finishes; partial cancelled recordings need not be valid.
The example displays FFmpeg media time, percentage and bytes written from live
statistics callbacks. A percentage may be indeterminate for unbounded media.

Serve the application with `Cross-Origin-Opener-Policy: same-origin` and
`Cross-Origin-Embedder-Policy: require-corp`; SharedArrayBuffer, workers and the
staged loader/Wasm pair are required. The media server must grant CORS to the
application origin and expose `Content-Range` for Range responses. HTTPS pages
need HTTPS media with a browser-trusted certificate. CORS denial, offline hosts,
403/404 and malformed media must produce finite errors; inspect session output.
TLS and Range behavior follows browser networking and the verified runtime.

The proven local fixture uses H.264/AAC MP4 and MPEG-TS HLS. Do not infer support
for every codec, HLS encryption mode or authenticated redirect. Direct RTSP,
RTMP, raw sockets and DRM are unsupported. The 1 MiB transport budget excludes
decoder, XHR, log and recording memory. Bound recordings and delete old output.
