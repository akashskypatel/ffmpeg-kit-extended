import {getBackend} from './platform/backend-registry';
import {argumentsToString, parseArguments} from './arguments';
import {LogLevel, SessionState, Signal} from './types';
import {SessionQueueManager} from './session-queue-manager';

const NativeFFmpegKitExtended = getBackend();

/**
 * Global FFmpegKit runtime configuration and utility methods.
 *
 * Settings apply process-wide and affect subsequently executed sessions. Call
 * `FFmpegKitExtended.initialize()` before using native configuration methods.
 */
export class FFmpegKitConfig {
  /**
   * Explicitly enables process-wide native log redirection.
   *
   * Installing an internal completion/log/statistics bridge does not call this
   * method implicitly; the native redirection setting remains user authority.
   */
  static enableRedirection(): void {
    NativeFFmpegKitExtended.enableRedirection();
  }

  /**
   * Explicitly disables process-wide native log redirection.
   *
   * This is authoritative even when a session has an optional log consumer;
   * completion transport remains independent of log/statistics delivery.
   */
  static disableRedirection(): void {
    NativeFFmpegKitExtended.disableRedirection();
  }

  /** Sets the minimum process-wide FFmpeg log level. */
  static setLogLevel(level: LogLevel): void {
    NativeFFmpegKitExtended.setLogLevel(level);
  }

  /** Returns the current process-wide FFmpeg log level. */
  static getLogLevel(): LogLevel {
    return NativeFFmpegKitExtended.getLogLevel() as LogLevel;
  }

  /** Converts a numeric `LogLevel` to the native display name. */
  static logLevelToString(level: LogLevel): string {
    return NativeFFmpegKitExtended.logLevelToString(level);
  }

  /**
   * Registers a directory for fontconfig-based filters such as `drawtext` and
   * `subtitles`.
   *
   * `mapping` optionally maps font family names to filenames in the directory.
   */
  static setFontDirectory(path: string, mapping?: Record<string, string>): void {
    NativeFFmpegKitExtended.setFontDirectory(
      path,
      mapping ? JSON.stringify(mapping) : '',
    );
  }

  /** Sets a native environment variable used by FFmpeg and its libraries. */
  static setEnvironmentVariable(name: string, value: string): void {
    NativeFFmpegKitExtended.setEnvironmentVariable(name, value);
  }

  /** Configures the native runtime to ignore one supported process signal. */
  static ignoreSignal(signal: Signal): void {
    NativeFFmpegKitExtended.ignoreSignal(signal);
  }

  /**
   * Selects the native audio output device by the name returned from
   * `listAudioOutputDevices()`.
   */
  static setAudioOutputDevice(deviceName: string): void {
    NativeFFmpegKitExtended.setAudioOutputDevice(deviceName);
  }

  /**
   * Returns native audio output devices in the wrapper's serialized text form.
   * The exact device names and formatting are platform/backend dependent.
   */
  static listAudioOutputDevices(): string {
    return NativeFFmpegKitExtended.listAudioOutputDevices();
  }

  /** Returns the bundled upstream FFmpeg version. */
  static getFFmpegVersion(): string {
    return NativeFFmpegKitExtended.getFFmpegVersion();
  }

  /** Returns the FFmpegKit Extended wrapper version. */
  static getVersion(): string {
    return NativeFFmpegKitExtended.getVersion();
  }

  /** Returns the selected native package/bundle name. */
  static getPackageName(): string {
    return NativeFFmpegKitExtended.getPackageName();
  }

  /**
   * Sets the maximum number of completed/created sessions retained natively.
   * Reducing the value may discard older history entries.
   */
  static setSessionHistorySize(size: number): void {
    NativeFFmpegKitExtended.setSessionHistorySize(size);
  }

  /** Returns the native session-history capacity. */
  static getSessionHistorySize(): number {
    return NativeFFmpegKitExtended.getSessionHistorySize();
  }

  /**
   * Clears the native session registry and retained session history.
   *
   * Do not call this while sessions are running. Clearing sessions can
   * cancel/invalidate active session handles, and Session getters for cleared
   * IDs may subsequently fail.
   */
  static clearSessions(): void {
    NativeFFmpegKitExtended.clearSessions();
  }

  /**
   * Creates a named FIFO/pipe path for streaming data into or out of FFmpeg.
   * Returns `undefined` when the native platform cannot create the pipe.
   */
  static registerNewFFmpegPipe(): string | undefined {
    return NativeFFmpegKitExtended.registerNewFFmpegPipe() || undefined;
  }

  /** Closes and removes a pipe created by `registerNewFFmpegPipe()`. */
  static closeFFmpegPipe(path: string): void {
    NativeFFmpegKitExtended.closeFFmpegPipe(path);
  }

  /** Returns the enum name for a `SessionState`. */
  static sessionStateToString(state: SessionState): string {
    return SessionState[state] ?? 'Failed';
  }

  /** Splits a command string using the package's platform-neutral parser. */
  static parseArguments(command: string): string[] {
    return parseArguments(command);
  }

  /** Quotes pre-tokenized arguments as one FFmpegKit command string. */
  static argumentsToString(arguments_: readonly string[]): string {
    return argumentsToString(arguments_);
  }

  /**
   * Returns the count of native log/statistics messages still being delivered
   * for a session. This is primarily useful for shutdown diagnostics.
   */
  static messagesInTransmit(sessionId: number): number {
    return NativeFFmpegKitExtended.messagesInTransmit(sessionId);
  }

  /** Returns the JavaScript session queue concurrency limit. */
  static getMaxConcurrentSessions(): number {
    return SessionQueueManager.shared.maxConcurrentSessions;
  }

  /** Sets the JavaScript session queue concurrency limit. */
  static setMaxConcurrentSessions(value: number): void {
    SessionQueueManager.shared.maxConcurrentSessions = value;
  }
}
