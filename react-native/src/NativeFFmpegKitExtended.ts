/**
 * Low-level React Native TurboModule contract generated into each platform.
 *
 * The interface keeps structured session/result payloads as JSON strings while
 * allowing pre-tokenized FFmpeg/FFplay arguments to cross as string arrays.
 * Most applications should use the higher-level exported classes, which create
 * typed sessions, poll callbacks, enforce queue limits, release native handles,
 * and parse media information. Direct calls require the caller to preserve
 * those lifecycle rules manually.
 *
 * @category Advanced / native bridge
 * @remarks This native entry is exported by `src/index.ts` only. The Web entry
 * `src/index.web.ts` deliberately omits it. Prefer the high-level wrappers for
 * cross-platform application code.
 */
import type {TurboModule} from 'react-native';
import {TurboModuleRegistry} from 'react-native';
import type {
  Double,
  EventEmitter,
  Int32,
} from 'react-native/Libraries/Types/CodegenTypes';

/**
 * Structured v2 log payload emitted after the native message is copied.
 * `sequence` is the native insertion order. The bridge owns and releases the
 * native payload before exposing this managed string to JavaScript.
 */
export type LogEvent = {
  /** Native process identity associated with the log entry. */
  sessionId: Double;
  /** Monotonic native insertion sequence for the entry. */
  sequence: Double;
  /** Native log severity. */
  level: Int32;
  /** Managed log message text. */
  message: string;
};

/**
 * Stable consumer-facing type-only view of the structured v2 log event emitted
 * after the native message is copied. The native Codegen payload remains an
 * internal implementation contract while this public type uses ordinary
 * JavaScript numeric values.
 *
 * @category Advanced / native bridge
 */
export type NativeFFmpegKitExtendedLogEvent = {
  /** Native process identity associated with the log entry. */
  sessionId: number;
  /** Monotonic native insertion sequence for the entry. */
  sequence: number;
  /** Native log severity. */
  level: number;
  /** Managed log message text. */
  message: string;
};

/** Native Codegen surface. Prefer the public wrappers unless integrating a framework. */
export interface Spec extends TurboModule {
  /** Initializes the native library selected by the consuming app configuration. */
  initialize(): Promise<void>;
  /** Consumes a synchronous Windows result diagnostic from the same call boundary. */
  consumeSynchronousError(): string;
  getBuildStamp(): string;

  /** Session creation/execution methods. Commands omit executable names. */
  createFFmpegSession(command: string): Double;
  /** Creates an FFmpeg session from pre-tokenized arguments. */
  createFFmpegSessionFromArguments(arguments_: ReadonlyArray<string>): Double;
  createFFprobeSession(command: string): Double;
  createFFplaySession(command: string): Double;
  /** Creates an FFplay session from pre-tokenized arguments. */
  createFFplaySessionFromArguments(arguments_: ReadonlyArray<string>): Double;
  createMediaInformationSession(command: string): Double;
  /** Creates the standard media-information probe without command-string reparsing. */
  createMediaInformationSessionFromPath(path: string): Double;
  executeSessionAsync(sessionId: Double, timeoutMs: Double): Promise<void>;
  cancelSession(sessionId: Double): Promise<void>;

  /** Process-wide structured v2 log stream; history polling is the fallback. */
  readonly onLogEvent: EventEmitter<LogEvent>;
  installLogBridge(): Promise<void>;
  uninstallLogBridge(): Promise<void>;

  /** Session snapshots and buffered callback payloads are serialized as JSON. */
  getSessionJson(sessionId: Double): string;
  /** Returns only the native lifecycle state for monitor polling. */
  getSessionState(sessionId: Double): Int32;
  /**
   * Returns the retained native log count for one bounded terminal
   * reconciliation. Normal direct delivery does not call indexed getters.
   */
  getLogsCount(sessionId: Double): Double;
  releaseSessionHandle(sessionId: Double): Promise<void>;
  /** Removes wrapper history for a queued session discarded before execution. */
  abandonCreatedSession(sessionId: Double): Promise<void>;
  getSessionsJson(kind: string): string;
  getLastSessionJson(kind: string): string;
  getLogsJson(sessionId: Double, fromIndex: Double): string;
  getStatisticsJson(sessionId: Double, fromIndex: Double): string;
  getMediaInformationJson(sessionId: Double): string;

  /** Session-scoped FFplay controls; positions and durations use seconds. */
  ffplayStart(sessionId: Double): Promise<void>;
  ffplayPause(sessionId: Double): Promise<void>;
  ffplayResume(sessionId: Double): Promise<void>;
  ffplayStop(sessionId: Double): Promise<void>;
  ffplaySeek(sessionId: Double, seconds: Double): Promise<void>;
  ffplayGetPosition(sessionId: Double): Double;
  ffplaySetPosition(sessionId: Double, seconds: Double): Promise<void>;
  ffplayGetDuration(sessionId: Double): Double;
  ffplayGetVideoWidth(sessionId: Double): Int32;
  ffplayGetVideoHeight(sessionId: Double): Int32;
  ffplayIsPlaying(sessionId: Double): boolean;
  ffplayIsPaused(sessionId: Double): boolean;
  ffplaySetVolume(sessionId: Double, volume: Double): Promise<void>;
  ffplayGetVolume(sessionId: Double): Double;
  ffplayHasVideoStream(path: string): boolean;

  /** Process-wide runtime configuration. */
  enableRedirection(): Promise<void>;
  disableRedirection(): Promise<void>;
  setLogLevel(level: Int32): Promise<void>;
  getLogLevel(): Int32;
  logLevelToString(level: Int32): string;
  setFontDirectory(path: string, mappingJson: string): Promise<void>;
  setEnvironmentVariable(name: string, value: string): Promise<void>;
  ignoreSignal(signal: Int32): Promise<void>;
  setAudioOutputDevice(deviceName: string): Promise<void>;
  listAudioOutputDevices(): string;

  /** Build, license, and compiled-feature introspection. */
  getFFmpegVersion(): string;
  getFFmpegArchitecture(): string;
  getVersion(): string;
  getPackageName(): string;
  getExternalLibraries(): string;
  getBundleType(): string;
  isGpl(): boolean;
  isNonfree(): boolean;
  getRegisteredCodecs(): string;
  getRegisteredEncoders(): string;
  getRegisteredDecoders(): string;
  getRegisteredMuxers(): string;
  getRegisteredDemuxers(): string;
  getRegisteredFilters(): string;
  getRegisteredProtocols(): string;
  getRegisteredBitstreamFilters(): string;
  getBuildConfiguration(): string;
  getBuildDate(): string;

  /** Session history, pipes, callback diagnostics, and per-session debug logs. */
  setSessionHistorySize(size: Double): Promise<void>;
  getSessionHistorySize(): Double;
  clearSessions(): Promise<void>;
  registerNewFFmpegPipe(): string;
  closeFFmpegPipe(path: string): Promise<void>;
  messagesInTransmit(sessionId: Double): Double;

  enableDebugLog(sessionId: Double): Promise<void>;
  disableDebugLog(sessionId: Double): Promise<void>;
  isDebugLogEnabled(sessionId: Double): boolean;
  getDebugLog(sessionId: Double): string;
  clearDebugLog(sessionId: Double): Promise<void>;
}

/**
 * Stable native-only contract for advanced integrations and diagnostics.
 *
 * Most applications should use the high-level wrappers. Direct use requires
 * the caller to preserve session lifetime, retained-handle, callback-demand,
 * and history rules normally owned by those wrappers. This explicit contract
 * keeps the complete low-level method inventory visible to generated docs
 * without adding a JavaScript export or changing Codegen's parser-compatible
 * declaration.
 * The runtime module is exported from the native entry point only; Web has no
 * native module value.
 *
 * @category Advanced / native bridge
 */
export type NativeFFmpegKitExtendedSpec = {
  /** Initializes the native library selected by the consuming app configuration. */
  initialize(): Promise<void>;
  /** Consumes a synchronous Windows result diagnostic from the same call boundary. */
  consumeSynchronousError(): string;
  /** Returns the wrapper/native build stamp. */
  getBuildStamp(): string;

  /** Creates an FFmpeg session from a command string. */
  createFFmpegSession(command: string): number;
  /** Creates an FFmpeg session from pre-tokenized arguments. */
  createFFmpegSessionFromArguments(arguments_: ReadonlyArray<string>): number;
  /** Creates an FFprobe session from a command string. */
  createFFprobeSession(command: string): number;
  /** Creates an FFplay session from a command string. */
  createFFplaySession(command: string): number;
  /** Creates an FFplay session from pre-tokenized arguments. */
  createFFplaySessionFromArguments(arguments_: ReadonlyArray<string>): number;
  /** Creates a media-information session from a command string. */
  createMediaInformationSession(command: string): number;
  /** Creates a media-information session for a path. */
  createMediaInformationSessionFromPath(path: string): number;
  /** Executes a native session asynchronously with a millisecond timeout. */
  executeSessionAsync(sessionId: number, timeoutMs: number): Promise<void>;
  /** Requests cancellation of a native session. */
  cancelSession(sessionId: number): Promise<void>;

  /** Receives structured native log events. */
  readonly onLogEvent: EventEmitter<NativeFFmpegKitExtendedLogEvent>;
  /** Installs the process-wide structured log bridge. */
  installLogBridge(): Promise<void>;
  /** Removes the process-wide structured log bridge. */
  uninstallLogBridge(): Promise<void>;

  /** Returns one session snapshot as serialized JSON. */
  getSessionJson(sessionId: number): string;
  /** Returns the native lifecycle state for one session. */
  getSessionState(sessionId: number): number;
  /** Returns the retained native log count for one session. */
  getLogsCount(sessionId: number): number;
  /** Releases the retained native handle for one session. */
  releaseSessionHandle(sessionId: number): Promise<void>;
  /** Removes wrapper history for a queued session discarded before execution. */
  abandonCreatedSession(sessionId: number): Promise<void>;
  /** Returns session snapshots for a kind as serialized JSON. */
  getSessionsJson(kind: string): string;
  /** Returns the latest session snapshot for a kind as serialized JSON. */
  getLastSessionJson(kind: string): string;
  /** Returns serialized log entries from a session starting at an index. */
  getLogsJson(sessionId: number, fromIndex: number): string;
  /** Returns serialized statistics from a session starting at an index. */
  getStatisticsJson(sessionId: number, fromIndex: number): string;
  /** Returns serialized media information for one session. */
  getMediaInformationJson(sessionId: number): string;

  /** Starts FFplay for one session. */
  ffplayStart(sessionId: number): Promise<void>;
  /** Pauses FFplay for one session. */
  ffplayPause(sessionId: number): Promise<void>;
  /** Resumes FFplay for one session. */
  ffplayResume(sessionId: number): Promise<void>;
  /** Stops FFplay for one session. */
  ffplayStop(sessionId: number): Promise<void>;
  /** Seeks FFplay to a position in seconds. */
  ffplaySeek(sessionId: number, seconds: number): Promise<void>;
  /** Returns the FFplay position in seconds. */
  ffplayGetPosition(sessionId: number): number;
  /** Sets the FFplay position in seconds. */
  ffplaySetPosition(sessionId: number, seconds: number): Promise<void>;
  /** Returns the FFplay duration in seconds. */
  ffplayGetDuration(sessionId: number): number;
  /** Returns the FFplay video width in pixels. */
  ffplayGetVideoWidth(sessionId: number): number;
  /** Returns the FFplay video height in pixels. */
  ffplayGetVideoHeight(sessionId: number): number;
  /** Reports whether FFplay is currently playing. */
  ffplayIsPlaying(sessionId: number): boolean;
  /** Reports whether FFplay is currently paused. */
  ffplayIsPaused(sessionId: number): boolean;
  /** Sets FFplay volume as a normalized numeric value. */
  ffplaySetVolume(sessionId: number, volume: number): Promise<void>;
  /** Returns the current FFplay volume. */
  ffplayGetVolume(sessionId: number): number;
  /** Reports whether a media path has a video stream. */
  ffplayHasVideoStream(path: string): boolean;

  /** Enables process-wide output redirection. */
  enableRedirection(): Promise<void>;
  /** Disables process-wide output redirection. */
  disableRedirection(): Promise<void>;
  /** Sets the native log level. */
  setLogLevel(level: number): Promise<void>;
  /** Returns the native log level. */
  getLogLevel(): number;
  /** Converts a native log level to display text. */
  logLevelToString(level: number): string;
  /** Sets the native font directory and mapping JSON. */
  setFontDirectory(path: string, mappingJson: string): Promise<void>;
  /** Sets one native environment variable. */
  setEnvironmentVariable(name: string, value: string): Promise<void>;
  /** Configures one native signal to be ignored. */
  ignoreSignal(signal: number): Promise<void>;
  /** Selects the native audio output device. */
  setAudioOutputDevice(deviceName: string): Promise<void>;
  /** Returns available native audio output devices as serialized JSON. */
  listAudioOutputDevices(): string;

  /** Returns the bundled FFmpeg version. */
  getFFmpegVersion(): string;
  /** Returns the bundled FFmpeg architecture. */
  getFFmpegArchitecture(): string;
  /** Returns the wrapper version. */
  getVersion(): string;
  /** Returns the native package name. */
  getPackageName(): string;
  /** Returns the compiled external-library inventory. */
  getExternalLibraries(): string;
  /** Returns the native bundle type. */
  getBundleType(): string;
  /** Reports whether the bundle includes GPL components. */
  isGpl(): boolean;
  /** Reports whether the bundle includes non-free components. */
  isNonfree(): boolean;
  /** Returns registered codec names as serialized JSON. */
  getRegisteredCodecs(): string;
  /** Returns registered encoder names as serialized JSON. */
  getRegisteredEncoders(): string;
  /** Returns registered decoder names as serialized JSON. */
  getRegisteredDecoders(): string;
  /** Returns registered muxer names as serialized JSON. */
  getRegisteredMuxers(): string;
  /** Returns registered demuxer names as serialized JSON. */
  getRegisteredDemuxers(): string;
  /** Returns registered filter names as serialized JSON. */
  getRegisteredFilters(): string;
  /** Returns registered protocol names as serialized JSON. */
  getRegisteredProtocols(): string;
  /** Returns registered bitstream-filter names as serialized JSON. */
  getRegisteredBitstreamFilters(): string;
  /** Returns the native build configuration. */
  getBuildConfiguration(): string;
  /** Returns the native build date. */
  getBuildDate(): string;

  /** Sets the retained native session-history size. */
  setSessionHistorySize(size: number): Promise<void>;
  /** Returns the retained native session-history size. */
  getSessionHistorySize(): number;
  /** Clears retained native session history. */
  clearSessions(): Promise<void>;
  /** Registers and returns a native FFmpeg pipe path. */
  registerNewFFmpegPipe(): string;
  /** Closes a native FFmpeg pipe path. */
  closeFFmpegPipe(path: string): Promise<void>;
  /** Returns the number of messages currently in transmission. */
  messagesInTransmit(sessionId: number): number;
  /** Enables per-session native debug logging. */
  enableDebugLog(sessionId: number): Promise<void>;
  /** Disables per-session native debug logging. */
  disableDebugLog(sessionId: number): Promise<void>;
  /** Reports whether per-session native debug logging is enabled. */
  isDebugLogEnabled(sessionId: number): boolean;
  /** Returns the per-session native debug log. */
  getDebugLog(sessionId: number): string;
  /** Clears the per-session native debug log. */
  clearDebugLog(sessionId: number): Promise<void>;
};

type NativeCodegenSurface = Omit<Spec, keyof TurboModule>;

type IsExactlyAssignable<First, Second> =
  [First] extends [Second]
    ? [Second] extends [First]
      ? true
      : false
    : false;

type Assert<T extends true> = T;

// This alias is intentionally unused at runtime; its constraint is the parity gate.
// eslint-disable-next-line @typescript-eslint/no-unused-vars
type NativeContractParity = Assert<
  IsExactlyAssignable<NativeCodegenSurface, NativeFFmpegKitExtendedSpec>
>;

/**
 * Enforced native module instance. Importing the package on a host where the
 * native library was not linked causes React Native to report a missing module
 * rather than silently returning `null`.
 *
 * @category Advanced / native bridge
 * @remarks This export exists on native `src/index.ts` only and is intentionally
 * absent from `src/index.web.ts`. Prefer the high-level wrappers for
 * cross-platform application code.
 */
export default TurboModuleRegistry.getEnforcing<Spec>(
  'FFmpegKitExtended'
) as NativeFFmpegKitExtendedSpec;
