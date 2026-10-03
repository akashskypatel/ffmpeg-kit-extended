import type {MediaInformationData} from '../media-information';

export interface StatisticsSnapshot {
  sessionId: number;
  videoFrameNumber: number;
  videoFps: number;
  videoQuality: number;
  size: number;
  time: number;
  timeElapsed: number;
  bitrate: number;
  speed: number;
  dupFrames: number;
  dropFrames: number;
}

/**
 * Options used by `FFmpegKitExtended.initialize()` to configure package startup.
 * Native targets normally use their bundled runtime and do not need these
 * options. On Web/Wasm, `assetBaseUrl` overrides the browser directory that
 * contains the staged runtime assets. A failed initialization can be retried
 * through `FFmpegKitExtended.initialize()` with corrected options.
 *
 * @category Configuration
 */
export interface FFmpegKitInitializeOptions {
  /** Browser asset directory containing the staged Wasm runtime. */
  assetBaseUrl?: string;
}

/**
 * One owned-v2 log event after its native message has become a JS string.
 * Native ownership ends inside the platform bridge; consumers retain only this
 * managed value and use `sequence` for ordering/deduplication.
 */
export interface LogEvent {
  sessionId: number;
  sequence: number;
  level: number;
  message: string;
}

/** Subscription returned by the native TurboModule or Web event bridge. */
export interface LogEventSubscription {
  remove(): void;
}

export type LogEventHandler = (event: LogEvent) => void;

/** A native action may complete synchronously on Web or asynchronously natively. */
export type ActionCompletion = void | Promise<void>;

export interface FFplayFrameMetadata {
  width: number;
  height: number;
  linesize: number;
  generation: number;
}

export interface FFplayFrameCopyResult extends FFplayFrameMetadata {
  copied: boolean;
}

/**
 * Platform-neutral implementation of the public FFmpegKit bridge.
 *
 * Direct v2 events are the normal live path. The indexed getters remain for
 * public history, v1 compatibility, and the single bounded terminal gap read.
 */
export interface FFmpegKitBackend {
  initialize(options?: FFmpegKitInitializeOptions): Promise<void>;
  getBuildStamp(): string;
  createFFmpegSession(command: string): number;
  createFFmpegSessionFromArguments(arguments_: readonly string[]): number;
  createFFprobeSession(command: string): number;
  createFFplaySession(command: string): number;
  createFFplaySessionFromArguments(arguments_: readonly string[]): number;
  createMediaInformationSession(command: string): number;
  createMediaInformationSessionFromPath(path: string): number;
  executeSessionAsync(sessionId: number, timeoutMs: number): ActionCompletion;
  /** Internal callback-demand seams; direct v2 transports may implement them. */
  installCompletionBridge?(): ActionCompletion;
  uninstallCompletionBridge?(): ActionCompletion;
  installLogBridge?(): ActionCompletion;
  uninstallLogBridge?(): ActionCompletion;
  /** Structured v2 log events; buffered polling is the compatibility fallback. */
  onLogEvent?(handler: LogEventHandler): LogEventSubscription;
  isDirectLogBridgeActive?(): boolean;
  /** Reads the retained native log count once for terminal reconciliation. */
  getLogsCount?(sessionId: number): number;
  installStatisticsBridge?(): void;
  uninstallStatisticsBridge?(): void;
  cancelSession(sessionId: number): ActionCompletion;
  /** Lightweight scalar state read used by the execution monitor. */
  getSessionState(sessionId: number): number;
  getSessionJson(sessionId: number): string;
  releaseSessionHandle(sessionId: number): ActionCompletion;
  /** Removes a definitively discarded pre-execution Created identity. */
  abandonCreatedSession(sessionId: number): ActionCompletion;
  /** Returns true for an ID durably abandoned before execution. */
  isSessionAbandoned?(sessionId: number): boolean;
  /** Records cancellation intent independently from Created abandonment. */
  recordCancellationIntent?(sessionId: number): void;
  /** Returns true when cancellation intent is durable for this ID. */
  isCancellationRequested?(sessionId: number): boolean;
  /** Clears cancellation intent after terminal observation or history clear. */
  clearCancellationIntent?(sessionId: number): void;
  getSessionsJson(kind: string): string;
  getLastSessionJson(kind: string): string;
  getLogsJson(sessionId: number, fromIndex: number): string;
  getStatisticsJson(sessionId: number, fromIndex: number): string;
  getMediaInformationJson(sessionId: number): string;
  ffplayStart(sessionId: number): ActionCompletion;
  ffplayPause(sessionId: number): ActionCompletion;
  ffplayResume(sessionId: number): ActionCompletion;
  ffplayStop(sessionId: number): ActionCompletion;
  ffplaySeek(sessionId: number, seconds: number): ActionCompletion;
  ffplayGetPosition(sessionId: number): number;
  ffplaySetPosition(sessionId: number, seconds: number): ActionCompletion;
  ffplayGetDuration(sessionId: number): number;
  ffplayGetVideoWidth(sessionId: number): number;
  ffplayGetVideoHeight(sessionId: number): number;
  ffplayIsPlaying(sessionId: number): boolean;
  ffplayIsPaused(sessionId: number): boolean;
  ffplaySetVolume(sessionId: number, volume: number): ActionCompletion;
  ffplayGetVolume(sessionId: number): number;
  ffplayHasVideoStream(path: string): boolean;
  getFrameBufferSize(): number;
  copyFrame(destination: number, destinationSize: number): FFplayFrameCopyResult;
  enableRedirection(): ActionCompletion;
  disableRedirection(): ActionCompletion;
  setLogLevel(level: number): ActionCompletion;
  getLogLevel(): number;
  logLevelToString(level: number): string;
  setFontDirectory(path: string, mappingJson: string): ActionCompletion;
  setEnvironmentVariable(name: string, value: string): ActionCompletion;
  ignoreSignal(signal: number): ActionCompletion;
  setAudioOutputDevice(deviceName: string): ActionCompletion;
  listAudioOutputDevices(): string;
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
  setSessionHistorySize(size: number): ActionCompletion;
  getSessionHistorySize(): number;
  clearSessions(): ActionCompletion;
  registerNewFFmpegPipe(): string;
  closeFFmpegPipe(path: string): ActionCompletion;
  messagesInTransmit(sessionId: number): number;
  enableDebugLog(sessionId: number): ActionCompletion;
  disableDebugLog(sessionId: number): ActionCompletion;
  isDebugLogEnabled(sessionId: number): boolean;
  getDebugLog(sessionId: number): string;
  clearDebugLog(sessionId: number): ActionCompletion;
  getMediaInformationData(sessionId: number): MediaInformationData | undefined;
}

let backend: FFmpegKitBackend | undefined;

/** Registers the backend selected by the package entrypoint. */
export function setBackend(value: FFmpegKitBackend): void {
  backend = value;
}

/** Returns the backend selected by the native or browser package entrypoint. */
export function getBackend(): FFmpegKitBackend {
  if (!backend) {
    throw new Error('FFmpegKit backend has not been configured by the package entrypoint.');
  }
  return backend;
}
