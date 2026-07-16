import NativeFFmpegKitExtended from './NativeFFmpegKitExtended';
import {argumentsToString, parseArguments} from './arguments';
import {LogLevel, SessionState, Signal} from './types';
import {SessionQueueManager} from './session-queue-manager';

export class FFmpegKitConfig {
  static enableRedirection(): void {
    NativeFFmpegKitExtended.enableRedirection();
  }

  static disableRedirection(): void {
    NativeFFmpegKitExtended.disableRedirection();
  }

  static setLogLevel(level: LogLevel): void {
    NativeFFmpegKitExtended.setLogLevel(level);
  }

  static getLogLevel(): LogLevel {
    return NativeFFmpegKitExtended.getLogLevel() as LogLevel;
  }

  static logLevelToString(level: LogLevel): string {
    return NativeFFmpegKitExtended.logLevelToString(level);
  }

  static setFontDirectory(path: string, mapping?: Record<string, string>): void {
    NativeFFmpegKitExtended.setFontDirectory(
      path,
      mapping ? JSON.stringify(mapping) : '',
    );
  }

  static setEnvironmentVariable(name: string, value: string): void {
    NativeFFmpegKitExtended.setEnvironmentVariable(name, value);
  }

  static ignoreSignal(signal: Signal): void {
    NativeFFmpegKitExtended.ignoreSignal(signal);
  }

  static setAudioOutputDevice(deviceName: string): void {
    NativeFFmpegKitExtended.setAudioOutputDevice(deviceName);
  }

  static listAudioOutputDevices(): string {
    return NativeFFmpegKitExtended.listAudioOutputDevices();
  }

  static getFFmpegVersion(): string {
    return NativeFFmpegKitExtended.getFFmpegVersion();
  }

  static getVersion(): string {
    return NativeFFmpegKitExtended.getVersion();
  }

  static getPackageName(): string {
    return NativeFFmpegKitExtended.getPackageName();
  }

  static setSessionHistorySize(size: number): void {
    NativeFFmpegKitExtended.setSessionHistorySize(size);
  }

  static getSessionHistorySize(): number {
    return NativeFFmpegKitExtended.getSessionHistorySize();
  }

  static clearSessions(): void {
    NativeFFmpegKitExtended.clearSessions();
  }

  static registerNewFFmpegPipe(): string | undefined {
    return NativeFFmpegKitExtended.registerNewFFmpegPipe() || undefined;
  }

  static closeFFmpegPipe(path: string): void {
    NativeFFmpegKitExtended.closeFFmpegPipe(path);
  }

  static sessionStateToString(state: SessionState): string {
    return SessionState[state] ?? 'Failed';
  }

  static parseArguments(command: string): string[] {
    return parseArguments(command);
  }

  static argumentsToString(arguments_: readonly string[]): string {
    return argumentsToString(arguments_);
  }

  static messagesInTransmit(sessionId: number): number {
    return NativeFFmpegKitExtended.messagesInTransmit(sessionId);
  }

  static getMaxConcurrentSessions(): number {
    return SessionQueueManager.shared.maxConcurrentSessions;
  }

  static setMaxConcurrentSessions(value: number): void {
    SessionQueueManager.shared.maxConcurrentSessions = value;
  }
}
