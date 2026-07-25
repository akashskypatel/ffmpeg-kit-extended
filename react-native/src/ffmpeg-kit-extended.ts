import NativeFFmpegKitExtended from './NativeFFmpegKitExtended';
import {
  FFmpegSession,
  FFplaySession,
  FFprobeSession,
  MediaInformationSession,
  parseSessionJson,
  parseSessionsJson,
  type Session,
} from './session';
import {SessionQueueManager} from './session-queue-manager';
import {LogLevel, Signal} from './types';

/**
 * Central lifecycle, session-history, build-introspection, and native utility
 * facade.
 *
 * Call `initialize()` exactly once near application startup before invoking
 * FFmpegKit APIs. Initialization is idempotent in JavaScript. Most command
 * execution should go through `FFmpegKit`, `FFprobeKit`, or `FFplayKit`; the
 * session factory methods here are useful for framework-style integrations.
 */
export class FFmpegKitExtended {
  private static initializedValue = false;

  /**
   * Loads and initializes the configured native FFmpegKit bundle.
   * Repeated calls are ignored after successful JavaScript initialization.
   */
  static initialize(): void {
    if (this.initializedValue) return;
    NativeFFmpegKitExtended.initialize();
    this.initializedValue = true;
  }

  /** Whether `initialize()` has completed in this JavaScript runtime. */
  static get initialized(): boolean {
    return this.initializedValue;
  }

  /** Throws a descriptive error when initialization has not occurred. */
  static requireInitialized(): void {
    if (!this.initializedValue) {
      throw new Error(
        'FFmpegKitExtended has not been initialized. Call FFmpegKitExtended.initialize() before using the package.',
      );
    }
  }

  /** Returns the native bundle build stamp used for diagnostics. */
  static getBuildStamp(): string {
    this.requireInitialized();
    return NativeFFmpegKitExtended.getBuildStamp();
  }

  /** Creates an unstarted FFmpeg processing session. */
  static createFFmpegSession(command: string): FFmpegSession {
    this.requireInitialized();
    return new FFmpegSession(
      NativeFFmpegKitExtended.createFFmpegSession(command),
      command,
    );
  }

  /** Creates an unstarted FFprobe command session. */
  static createFFprobeSession(command: string): FFprobeSession {
    this.requireInitialized();
    return new FFprobeSession(
      NativeFFmpegKitExtended.createFFprobeSession(command),
      command,
    );
  }

  /** Creates an unstarted FFplay session with a native timeout in milliseconds. */
  static createFFplaySession(command: string, timeoutMs = 500): FFplaySession {
    this.requireInitialized();
    return new FFplaySession(
      NativeFFmpegKitExtended.createFFplaySession(command),
      command,
      timeoutMs,
    );
  }

  /**
   * Creates an unstarted structured media-information session from a complete
   * FFprobe command string.
   */
  static createMediaInformationSession(
    command: string,
    timeoutMs = 500,
  ): MediaInformationSession {
    this.requireInitialized();
    return new MediaInformationSession(
      NativeFFmpegKitExtended.createMediaInformationSession(command),
      command,
      timeoutMs,
    );
  }

  /** Requests cancellation by native session ID. */
  static cancelSession(sessionId: number): void {
    this.requireInitialized();
    NativeFFmpegKitExtended.cancelSession(sessionId);
  }

  /** Clears queued work and requests cancellation of all active sessions. */
  static cancelAllSessions(): void {
    this.requireInitialized();
    SessionQueueManager.shared.cancelAll();
  }

  /** Returns all sessions retained in native history. */
  static getSessions(): Session[] {
    this.requireInitialized();
    return parseSessionsJson(NativeFFmpegKitExtended.getSessionsJson('all'));
  }

  /** Alias of `getSessions()`. */
  static listSessions(): Session[] {
    return this.getSessions();
  }

  /** Returns retained FFmpeg processing sessions. */
  static getFFmpegSessions(): FFmpegSession[] {
    return parseSessionsJson(
      NativeFFmpegKitExtended.getSessionsJson('ffmpeg'),
    ).filter((session): session is FFmpegSession => session.isFFmpegSession());
  }

  /** Returns retained FFprobe command sessions. */
  static getFFprobeSessions(): FFprobeSession[] {
    return parseSessionsJson(
      NativeFFmpegKitExtended.getSessionsJson('ffprobe'),
    ).filter((session): session is FFprobeSession => session.isFFprobeSession());
  }

  /** Returns retained FFplay sessions. */
  static getFFplaySessions(): FFplaySession[] {
    return parseSessionsJson(
      NativeFFmpegKitExtended.getSessionsJson('ffplay'),
    ).filter((session): session is FFplaySession => session.isFFplaySession());
  }

  /** Returns retained structured media-information sessions. */
  static getMediaInformationSessions(): MediaInformationSession[] {
    return parseSessionsJson(
      NativeFFmpegKitExtended.getSessionsJson('media-information'),
    ).filter(
      (session): session is MediaInformationSession =>
        session.isMediaInformationSession(),
    );
  }

  /** Looks up one retained session by ID. */
  static getSession(sessionId: number): Session | undefined {
    this.requireInitialized();
    return parseSessionJson(NativeFFmpegKitExtended.getSessionJson(sessionId));
  }

  /** Returns the newest retained session of any type. */
  static getLastSession(): Session | undefined {
    this.requireInitialized();
    return parseSessionJson(NativeFFmpegKitExtended.getLastSessionJson('all'));
  }

  /** Returns the newest retained FFmpeg session. */
  static getLastFFmpegSession(): FFmpegSession | undefined {
    const session = parseSessionJson(
      NativeFFmpegKitExtended.getLastSessionJson('ffmpeg'),
    );
    return session?.isFFmpegSession() ? session : undefined;
  }

  /** Returns the newest retained FFprobe session. */
  static getLastFFprobeSession(): FFprobeSession | undefined {
    const session = parseSessionJson(
      NativeFFmpegKitExtended.getLastSessionJson('ffprobe'),
    );
    return session?.isFFprobeSession() ? session : undefined;
  }

  /** Returns the newest retained FFplay session. */
  static getLastFFplaySession(): FFplaySession | undefined {
    const session = parseSessionJson(
      NativeFFmpegKitExtended.getLastSessionJson('ffplay'),
    );
    return session?.isFFplaySession() ? session : undefined;
  }

  /** Returns the newest retained media-information session. */
  static getLastMediaInformationSession(): MediaInformationSession | undefined {
    const session = parseSessionJson(
      NativeFFmpegKitExtended.getLastSessionJson('media-information'),
    );
    return session?.isMediaInformationSession() ? session : undefined;
  }

  /** Enables native log redirection used by per-session callbacks. */
  static enableRedirection(): void {
    NativeFFmpegKitExtended.enableRedirection();
  }

  /** Disables native log redirection. */
  static disableRedirection(): void {
    NativeFFmpegKitExtended.disableRedirection();
  }

  /** Sets the process-wide FFmpeg log level. */
  static setLogLevel(level: LogLevel): void {
    NativeFFmpegKitExtended.setLogLevel(level);
  }

  /** Returns the process-wide FFmpeg log level. */
  static getLogLevel(): LogLevel {
    return NativeFFmpegKitExtended.getLogLevel() as LogLevel;
  }

  /** Registers fonts for FFmpeg filters, with an optional family-to-file map. */
  static setFontDirectory(path: string, mapping?: Record<string, string>): void {
    NativeFFmpegKitExtended.setFontDirectory(
      path,
      mapping ? JSON.stringify(mapping) : '',
    );
  }

  /** Selects a native audio output device by backend-provided name. */
  static setAudioOutputDevice(deviceName: string): void {
    NativeFFmpegKitExtended.setAudioOutputDevice(deviceName);
  }

  /** Lists native audio output devices in backend-defined text form. */
  static listAudioOutputDevices(): string {
    return NativeFFmpegKitExtended.listAudioOutputDevices();
  }

  /** Sets a native environment variable for FFmpeg and linked libraries. */
  static setEnvironmentVariable(name: string, value: string): void {
    NativeFFmpegKitExtended.setEnvironmentVariable(name, value);
  }

  /** Configures the native runtime to ignore a supported signal. */
  static ignoreSignal(signal: Signal): void {
    NativeFFmpegKitExtended.ignoreSignal(signal);
  }

  /** Returns the bundled upstream FFmpeg version. */
  static getFFmpegVersion(): string {
    return NativeFFmpegKitExtended.getFFmpegVersion();
  }

  /** Returns the architecture reported by the native FFmpeg build. */
  static getFFmpegArchitecture(): string {
    return NativeFFmpegKitExtended.getFFmpegArchitecture();
  }

  /** Returns the FFmpegKit Extended wrapper version. */
  static getVersion(): string {
    return NativeFFmpegKitExtended.getVersion();
  }

  /** Returns the configured native package name. */
  static getPackageName(): string {
    return NativeFFmpegKitExtended.getPackageName();
  }

  /** Lists external libraries enabled in the selected native bundle. */
  static getExternalLibraries(): string {
    return NativeFFmpegKitExtended.getExternalLibraries();
  }

  /** Returns the selected bundle type, such as shared/static build metadata. */
  static getBundleType(): string {
    return NativeFFmpegKitExtended.getBundleType();
  }

  /** Whether the selected native bundle includes GPL components. */
  static isGpl(): boolean {
    return NativeFFmpegKitExtended.isGpl();
  }

  /** Whether the selected native bundle includes nonfree components. */
  static isNonfree(): boolean {
    return NativeFFmpegKitExtended.isNonfree();
  }

  /** Returns the native FFmpeg codec registry text. */
  static getRegisteredCodecs(): string {
    return NativeFFmpegKitExtended.getRegisteredCodecs();
  }

  /** Returns the native FFmpeg encoder registry text. */
  static getRegisteredEncoders(): string {
    return NativeFFmpegKitExtended.getRegisteredEncoders();
  }

  /** Returns the native FFmpeg decoder registry text. */
  static getRegisteredDecoders(): string {
    return NativeFFmpegKitExtended.getRegisteredDecoders();
  }

  /** Returns the native FFmpeg muxer registry text. */
  static getRegisteredMuxers(): string {
    return NativeFFmpegKitExtended.getRegisteredMuxers();
  }

  /** Returns the native FFmpeg demuxer registry text. */
  static getRegisteredDemuxers(): string {
    return NativeFFmpegKitExtended.getRegisteredDemuxers();
  }

  /** Returns the native FFmpeg filter registry text. */
  static getRegisteredFilters(): string {
    return NativeFFmpegKitExtended.getRegisteredFilters();
  }

  /** Returns the native FFmpeg protocol registry text. */
  static getRegisteredProtocols(): string {
    return NativeFFmpegKitExtended.getRegisteredProtocols();
  }

  /** Returns the native FFmpeg bitstream-filter registry text. */
  static getRegisteredBitstreamFilters(): string {
    return NativeFFmpegKitExtended.getRegisteredBitstreamFilters();
  }

  /** Returns the upstream FFmpeg configure command/options. */
  static getBuildConfiguration(): string {
    return NativeFFmpegKitExtended.getBuildConfiguration();
  }

  /** Returns the native bundle build date text. */
  static getBuildDate(): string {
    return NativeFFmpegKitExtended.getBuildDate();
  }

  /** Sets the number of sessions retained in native history. */
  static setSessionHistorySize(size: number): void {
    NativeFFmpegKitExtended.setSessionHistorySize(size);
  }

  /** Returns the native session-history capacity. */
  static getSessionHistorySize(): number {
    return NativeFFmpegKitExtended.getSessionHistorySize();
  }

  /** Clears retained native session history. */
  static clearSessions(): void {
    NativeFFmpegKitExtended.clearSessions();
  }

  /** Creates a native FFmpeg FIFO/pipe and returns its path when supported. */
  static registerNewFFmpegPipe(): string | undefined {
    return NativeFFmpegKitExtended.registerNewFFmpegPipe() || undefined;
  }

  /** Closes/removes a pipe created by `registerNewFFmpegPipe()`. */
  static closeFFmpegPipe(path: string): void {
    NativeFFmpegKitExtended.closeFFmpegPipe(path);
  }

  /** Returns native callback messages still in transit for a session. */
  static messagesInTransmit(sessionId: number): number {
    return NativeFFmpegKitExtended.messagesInTransmit(sessionId);
  }
}
