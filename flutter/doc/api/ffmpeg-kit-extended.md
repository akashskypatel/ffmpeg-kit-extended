# FFmpegKitExtended API Reference

`FFmpegKitExtended` is the central initialized facade for advanced lifecycle,
history, package introspection, and global utility operations. Most application
code should start with the convenience classes [`FFmpegKit`](ffmpeg-kit.md),
[`FFprobeKit`](ffprobe-kit.md), and [`FFplayKit`](ffplay-kit.md). Use
[`FFmpegKitConfig`](config.md) for global settings and callbacks; use this
facade when the application needs the central history or package/runtime
introspection APIs.

## Initialization

```dart
static Future<void> initialize()
static bool get initialized
```

Call `await FFmpegKitExtended.initialize()` once before reaching the native
backend. Concurrent calls share one initialization attempt, successful
initialization is idempotent, and a failed Web initialization can be retried.
Methods that require the backend throw `StateError` when initialization has not
completed successfully.

## Session factories

These factories create wrapper sessions without starting execution. Blank
commands throw `ArgumentError`.

```dart
static FFmpegSession createFFmpegSession(
  String command, {
  FFmpegSessionCompleteCallback? completeCallback,
  FFmpegLogCallback? logCallback,
  FFmpegStatisticsCallback? statisticsCallback,
})

static FFprobeSession createFFprobeSession(
  String command, {
  FFprobeSessionCompleteCallback? completeCallback,
})

static FFplaySession createFFplaySession(
  String command, {
  FFplaySessionCompleteCallback? completeCallback,
  int timeout = 500,
})

static MediaInformationSession createMediaInformationSession(
  String command, {
  int timeout = 500,
  MediaInformationSessionCompleteCallback? completeCallback,
})
```

For ordinary command execution, prefer the matching convenience class so the
execution contract is explicit.

## Session management and history

```dart
static void cancelSession(int sessionId)
static void cancelAllSessions()
static List<Session> listSessions()
static List<Session> getSessions()
static Session? getSession(int sessionId)
static List<FFmpegSession> getFFmpegSessions()
static List<FFprobeSession> getFFprobeSessions()
static List<FFplaySession> getFFplaySessions()
static List<MediaInformationSession> getMediaInformationSessions()
static Session? getLastSession()
static FFmpegSession? getLastFFmpegSession()
static FFprobeSession? getLastFFprobeSession()
static FFplaySession? getLastFFplaySession()
static MediaInformationSession? getLastMediaInformationSession()
static Session? getLastCompletedSession()
static void clearSessions()
```

History getters return retained native history in creation order; they are not
an active-execution inventory. Use `SessionQueueManager().activeSessions` for
currently active asynchronous executions.

Passing `0` to `cancelSession(0)` is the compatibility form of
`cancelAllSessions()`: it attempts every active and queued execution and
reports the first cancellation error after all attempts. A nonzero ID targets
the available session with that ID.

## Package and build introspection

All of the following require successful initialization:

```dart
FFmpegKitExtended.getFFmpegVersion()
FFmpegKitExtended.getFFmpegArchitecture()
FFmpegKitExtended.getVersion()
FFmpegKitExtended.getPackageName()
FFmpegKitExtended.getBundleType()
FFmpegKitExtended.getExternalLibraries()
FFmpegKitExtended.isGpl()
FFmpegKitExtended.isNonfree()
FFmpegKitExtended.getRegisteredCodecs()
FFmpegKitExtended.getRegisteredEncoders()
FFmpegKitExtended.getRegisteredDecoders()
FFmpegKitExtended.getRegisteredMuxers()
FFmpegKitExtended.getRegisteredDemuxers()
FFmpegKitExtended.getRegisteredFilters()
FFmpegKitExtended.getRegisteredProtocols()
FFmpegKitExtended.getRegisteredBitstreamFilters()
FFmpegKitExtended.getBuildConfiguration()
FFmpegKitExtended.getBuildDate()
```

The registered-library methods return comma-separated native capability
strings. The GPL/non-free methods report the selected bundle capabilities.

## Audio, environment, signals, and utilities

```dart
FFmpegKitExtended.setAudioOutputDevice(String deviceName)
FFmpegKitExtended.listAudioOutputDevices()
FFmpegKitExtended.setEnvironmentVariable(String name, String value)
FFmpegKitExtended.ignoreSignal(Signal signal)
FFmpegKitExtended.parseArguments(String command)
FFmpegKitExtended.argumentsToString(List<String> arguments)
FFmpegKitExtended.messagesInTransmit(int sessionId)
FFmpegKitExtended.registerNewFFmpegPipe()
FFmpegKitExtended.closeFFmpegPipe(String pipePath)
```

Per-session debug helpers are available for advanced diagnostics:

```dart
FFmpegKitExtended.enableDebugLog(Session session)
FFmpegKitExtended.disableDebugLog(Session session)
FFmpegKitExtended.isDebugLogEnabled(Session session)
FFmpegKitExtended.getDebugLog(Session session)
FFmpegKitExtended.clearDebugLog(Session session)
```

`parseArguments` and `argumentsToString` are conversion utilities; use the
argument-list factories when token boundaries must be preserved.

## Advanced lifecycle support

The facade also exposes lifecycle-maintenance operations used by queue and
wrapper integrations, including cancellation-intent and abandoned-created
session reconciliation. These are advanced support APIs: normal applications
should use the convenience cancellation methods and allow the queue to own
terminal cleanup rather than manipulating lifecycle tombstones directly.

