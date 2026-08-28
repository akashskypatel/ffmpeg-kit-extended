/**
 * Low-level React Native TurboModule contract generated into each platform.
 *
 * The interface keeps structured session/result payloads as JSON strings while
 * allowing pre-tokenized FFmpeg/FFplay arguments to cross as string arrays.
 * Most applications should use the higher-level exported classes, which create
 * typed sessions, poll callbacks, enforce queue limits, release native handles,
 * and parse media information. Direct calls require the caller to preserve
 * those lifecycle rules manually.
 */
import type {TurboModule} from 'react-native';
import {TurboModuleRegistry} from 'react-native';
import type {Double, Int32} from 'react-native/Libraries/Types/CodegenTypes';

/** Native Codegen surface. Prefer the public wrappers unless integrating a framework. */
export interface Spec extends TurboModule {
  /** Initializes the native library selected by the consuming app configuration. */
  initialize(): void;
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
  executeSessionAsync(sessionId: Double, timeoutMs: Double): void;
  cancelSession(sessionId: Double): void;

  /** Session snapshots and buffered callback payloads are serialized as JSON. */
  getSessionJson(sessionId: Double): string;
  releaseSessionHandle(sessionId: Double): void;
  getSessionsJson(kind: string): string;
  getLastSessionJson(kind: string): string;
  getLogsJson(sessionId: Double, fromIndex: Double): string;
  getStatisticsJson(sessionId: Double, fromIndex: Double): string;
  getMediaInformationJson(sessionId: Double): string;

  /** Session-scoped FFplay controls; positions and durations use seconds. */
  ffplayStart(sessionId: Double): void;
  ffplayPause(sessionId: Double): void;
  ffplayResume(sessionId: Double): void;
  ffplayStop(sessionId: Double): void;
  ffplaySeek(sessionId: Double, seconds: Double): void;
  ffplayGetPosition(sessionId: Double): Double;
  ffplaySetPosition(sessionId: Double, seconds: Double): void;
  ffplayGetDuration(sessionId: Double): Double;
  ffplayGetVideoWidth(sessionId: Double): Int32;
  ffplayGetVideoHeight(sessionId: Double): Int32;
  ffplayIsPlaying(sessionId: Double): boolean;
  ffplayIsPaused(sessionId: Double): boolean;
  ffplaySetVolume(sessionId: Double, volume: Double): void;
  ffplayGetVolume(sessionId: Double): Double;
  ffplayHasVideoStream(path: string): boolean;

  /** Process-wide runtime configuration. */
  enableRedirection(): void;
  disableRedirection(): void;
  setLogLevel(level: Int32): void;
  getLogLevel(): Int32;
  logLevelToString(level: Int32): string;
  setFontDirectory(path: string, mappingJson: string): void;
  setEnvironmentVariable(name: string, value: string): void;
  ignoreSignal(signal: Int32): void;
  setAudioOutputDevice(deviceName: string): void;
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
  setSessionHistorySize(size: Double): void;
  getSessionHistorySize(): Double;
  clearSessions(): void;
  registerNewFFmpegPipe(): string;
  closeFFmpegPipe(path: string): void;
  messagesInTransmit(sessionId: Double): Double;

  enableDebugLog(sessionId: Double): void;
  disableDebugLog(sessionId: Double): void;
  isDebugLogEnabled(sessionId: Double): boolean;
  getDebugLog(sessionId: Double): string;
  clearDebugLog(sessionId: Double): void;
}

/**
 * Enforced native module instance. Importing the package on a host where the
 * native library was not linked causes React Native to report a missing module
 * rather than silently returning `null`.
 */
export default TurboModuleRegistry.getEnforcing<Spec>('FFmpegKitExtended');
