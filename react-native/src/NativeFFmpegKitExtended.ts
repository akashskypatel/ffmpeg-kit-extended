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
  sessionId: Double;
  sequence: Double;
  level: Int32;
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
 * Enforced native module instance. Importing the package on a host where the
 * native library was not linked causes React Native to report a missing module
 * rather than silently returning `null`.
 *
 * @category Advanced / native bridge
 * @remarks This export exists on native `src/index.ts` only and is intentionally
 * absent from `src/index.web.ts`. Prefer the high-level wrappers for
 * cross-platform application code.
 */
export default TurboModuleRegistry.getEnforcing<Spec>('FFmpegKitExtended');
