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

export class FFmpegKitExtended {
  private static initializedValue = false;

  static initialize(): void {
    if (this.initializedValue) return;
    NativeFFmpegKitExtended.initialize();
    this.initializedValue = true;
  }

  static get initialized(): boolean {
    return this.initializedValue;
  }

  static requireInitialized(): void {
    if (!this.initializedValue) {
      throw new Error(
        'FFmpegKitExtended has not been initialized. Call FFmpegKitExtended.initialize() before using the package.',
      );
    }
  }

  static getBuildStamp(): string {
    this.requireInitialized();
    return NativeFFmpegKitExtended.getBuildStamp();
  }

  static createFFmpegSession(command: string): FFmpegSession {
    this.requireInitialized();
    return new FFmpegSession(
      NativeFFmpegKitExtended.createFFmpegSession(command),
      command,
    );
  }

  static createFFprobeSession(command: string): FFprobeSession {
    this.requireInitialized();
    return new FFprobeSession(
      NativeFFmpegKitExtended.createFFprobeSession(command),
      command,
    );
  }

  static createFFplaySession(command: string, timeoutMs = 500): FFplaySession {
    this.requireInitialized();
    return new FFplaySession(
      NativeFFmpegKitExtended.createFFplaySession(command),
      command,
      timeoutMs,
    );
  }

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

  static cancelSession(sessionId: number): void {
    this.requireInitialized();
    NativeFFmpegKitExtended.cancelSession(sessionId);
  }

  static cancelAllSessions(): void {
    this.requireInitialized();
    SessionQueueManager.shared.cancelAll();
  }

  static getSessions(): Session[] {
    this.requireInitialized();
    return parseSessionsJson(NativeFFmpegKitExtended.getSessionsJson('all'));
  }

  static listSessions(): Session[] {
    return this.getSessions();
  }

  static getFFmpegSessions(): FFmpegSession[] {
    return parseSessionsJson(
      NativeFFmpegKitExtended.getSessionsJson('ffmpeg'),
    ).filter((session): session is FFmpegSession => session.isFFmpegSession());
  }

  static getFFprobeSessions(): FFprobeSession[] {
    return parseSessionsJson(
      NativeFFmpegKitExtended.getSessionsJson('ffprobe'),
    ).filter((session): session is FFprobeSession => session.isFFprobeSession());
  }

  static getFFplaySessions(): FFplaySession[] {
    return parseSessionsJson(
      NativeFFmpegKitExtended.getSessionsJson('ffplay'),
    ).filter((session): session is FFplaySession => session.isFFplaySession());
  }

  static getMediaInformationSessions(): MediaInformationSession[] {
    return parseSessionsJson(
      NativeFFmpegKitExtended.getSessionsJson('media-information'),
    ).filter(
      (session): session is MediaInformationSession =>
        session.isMediaInformationSession(),
    );
  }

  static getSession(sessionId: number): Session | undefined {
    this.requireInitialized();
    return parseSessionJson(NativeFFmpegKitExtended.getSessionJson(sessionId));
  }

  static getLastSession(): Session | undefined {
    this.requireInitialized();
    return parseSessionJson(NativeFFmpegKitExtended.getLastSessionJson('all'));
  }

  static getLastFFmpegSession(): FFmpegSession | undefined {
    const session = parseSessionJson(
      NativeFFmpegKitExtended.getLastSessionJson('ffmpeg'),
    );
    return session?.isFFmpegSession() ? session : undefined;
  }

  static getLastFFprobeSession(): FFprobeSession | undefined {
    const session = parseSessionJson(
      NativeFFmpegKitExtended.getLastSessionJson('ffprobe'),
    );
    return session?.isFFprobeSession() ? session : undefined;
  }

  static getLastFFplaySession(): FFplaySession | undefined {
    const session = parseSessionJson(
      NativeFFmpegKitExtended.getLastSessionJson('ffplay'),
    );
    return session?.isFFplaySession() ? session : undefined;
  }

  static getLastMediaInformationSession(): MediaInformationSession | undefined {
    const session = parseSessionJson(
      NativeFFmpegKitExtended.getLastSessionJson('media-information'),
    );
    return session?.isMediaInformationSession() ? session : undefined;
  }

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

  static setFontDirectory(path: string, mapping?: Record<string, string>): void {
    NativeFFmpegKitExtended.setFontDirectory(
      path,
      mapping ? JSON.stringify(mapping) : '',
    );
  }

  static setAudioOutputDevice(deviceName: string): void {
    NativeFFmpegKitExtended.setAudioOutputDevice(deviceName);
  }

  static listAudioOutputDevices(): string {
    return NativeFFmpegKitExtended.listAudioOutputDevices();
  }

  static setEnvironmentVariable(name: string, value: string): void {
    NativeFFmpegKitExtended.setEnvironmentVariable(name, value);
  }

  static ignoreSignal(signal: Signal): void {
    NativeFFmpegKitExtended.ignoreSignal(signal);
  }

  static getFFmpegVersion(): string {
    return NativeFFmpegKitExtended.getFFmpegVersion();
  }

  static getFFmpegArchitecture(): string {
    return NativeFFmpegKitExtended.getFFmpegArchitecture();
  }

  static getVersion(): string {
    return NativeFFmpegKitExtended.getVersion();
  }

  static getPackageName(): string {
    return NativeFFmpegKitExtended.getPackageName();
  }

  static getExternalLibraries(): string {
    return NativeFFmpegKitExtended.getExternalLibraries();
  }

  static getBundleType(): string {
    return NativeFFmpegKitExtended.getBundleType();
  }

  static isGpl(): boolean {
    return NativeFFmpegKitExtended.isGpl();
  }

  static isNonfree(): boolean {
    return NativeFFmpegKitExtended.isNonfree();
  }

  static getRegisteredCodecs(): string {
    return NativeFFmpegKitExtended.getRegisteredCodecs();
  }

  static getRegisteredEncoders(): string {
    return NativeFFmpegKitExtended.getRegisteredEncoders();
  }

  static getRegisteredDecoders(): string {
    return NativeFFmpegKitExtended.getRegisteredDecoders();
  }

  static getRegisteredMuxers(): string {
    return NativeFFmpegKitExtended.getRegisteredMuxers();
  }

  static getRegisteredDemuxers(): string {
    return NativeFFmpegKitExtended.getRegisteredDemuxers();
  }

  static getRegisteredFilters(): string {
    return NativeFFmpegKitExtended.getRegisteredFilters();
  }

  static getRegisteredProtocols(): string {
    return NativeFFmpegKitExtended.getRegisteredProtocols();
  }

  static getRegisteredBitstreamFilters(): string {
    return NativeFFmpegKitExtended.getRegisteredBitstreamFilters();
  }

  static getBuildConfiguration(): string {
    return NativeFFmpegKitExtended.getBuildConfiguration();
  }

  static getBuildDate(): string {
    return NativeFFmpegKitExtended.getBuildDate();
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

  static messagesInTransmit(sessionId: number): number {
    return NativeFFmpegKitExtended.messagesInTransmit(sessionId);
  }
}
