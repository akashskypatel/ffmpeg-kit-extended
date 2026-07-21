import type {TurboModule} from 'react-native';
import {TurboModuleRegistry} from 'react-native';
import type {Double, Int32} from 'react-native/Libraries/Types/CodegenTypes';

export interface Spec extends TurboModule {
  initialize(): void;
  getBuildStamp(): string;

  createFFmpegSession(command: string): Double;
  createFFprobeSession(command: string): Double;
  createFFplaySession(command: string): Double;
  createMediaInformationSession(command: string): Double;
  executeSessionAsync(sessionId: Double, timeoutMs: Double): void;
  cancelSession(sessionId: Double): void;

  getSessionJson(sessionId: Double): string;
  releaseSessionHandle(sessionId: Double): void;
  getSessionsJson(kind: string): string;
  getLastSessionJson(kind: string): string;
  getLogsJson(sessionId: Double, fromIndex: Double): string;
  getStatisticsJson(sessionId: Double, fromIndex: Double): string;
  getMediaInformationJson(sessionId: Double): string;

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

export default TurboModuleRegistry.getEnforcing<Spec>('FFmpegKitExtended');
