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

export interface FFmpegKitInitializeOptions {
  /** Browser asset directory containing the staged Wasm runtime. */
  assetBaseUrl?: string;
}

export interface FFplayFrameMetadata {
  width: number;
  height: number;
  linesize: number;
  generation: number;
}

export interface FFplayFrameCopyResult extends FFplayFrameMetadata {
  copied: boolean;
}

/** Platform-neutral implementation of the public FFmpegKit bridge. */
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
  executeSessionAsync(sessionId: number, timeoutMs: number): void;
  cancelSession(sessionId: number): void;
  /** Optional lightweight state read used by the Web monitor. */
  getSessionState?(sessionId: number): number;
  getSessionJson(sessionId: number): string;
  releaseSessionHandle(sessionId: number): void;
  getSessionsJson(kind: string): string;
  getLastSessionJson(kind: string): string;
  getLogsJson(sessionId: number, fromIndex: number): string;
  getStatisticsJson(sessionId: number, fromIndex: number): string;
  getMediaInformationJson(sessionId: number): string;
  ffplayStart(sessionId: number): void;
  ffplayPause(sessionId: number): void;
  ffplayResume(sessionId: number): void;
  ffplayStop(sessionId: number): void;
  ffplaySeek(sessionId: number, seconds: number): void;
  ffplayGetPosition(sessionId: number): number;
  ffplaySetPosition(sessionId: number, seconds: number): void;
  ffplayGetDuration(sessionId: number): number;
  ffplayGetVideoWidth(sessionId: number): number;
  ffplayGetVideoHeight(sessionId: number): number;
  ffplayIsPlaying(sessionId: number): boolean;
  ffplayIsPaused(sessionId: number): boolean;
  ffplaySetVolume(sessionId: number, volume: number): void;
  ffplayGetVolume(sessionId: number): number;
  ffplayHasVideoStream(path: string): boolean;
  getFrameBufferSize(): number;
  copyFrame(destination: number, destinationSize: number): FFplayFrameCopyResult;
  enableRedirection(): void;
  disableRedirection(): void;
  setLogLevel(level: number): void;
  getLogLevel(): number;
  logLevelToString(level: number): string;
  setFontDirectory(path: string, mappingJson: string): void;
  setEnvironmentVariable(name: string, value: string): void;
  ignoreSignal(signal: number): void;
  setAudioOutputDevice(deviceName: string): void;
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
  setSessionHistorySize(size: number): void;
  getSessionHistorySize(): number;
  clearSessions(): void;
  registerNewFFmpegPipe(): string;
  closeFFmpegPipe(path: string): void;
  messagesInTransmit(sessionId: number): number;
  enableDebugLog(sessionId: number): void;
  disableDebugLog(sessionId: number): void;
  isDebugLogEnabled(sessionId: number): boolean;
  getDebugLog(sessionId: number): string;
  clearDebugLog(sessionId: number): void;
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
