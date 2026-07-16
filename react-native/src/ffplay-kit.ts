import NativeFFmpegKitExtended from './NativeFFmpegKitExtended';
import {FFplaySession} from './session';
import type {ExecuteOptions} from './types';

export class FFplayKit {
  private static activeSession?: FFplaySession;

  static createSession(command: string, timeoutMs = 500): FFplaySession {
    if (!command.trim()) throw new Error('command must not be blank');
    return new FFplaySession(
      NativeFFmpegKitExtended.createFFplaySession(command),
      command,
      timeoutMs,
    );
  }

  static async execute(
    command: string,
    options: ExecuteOptions<FFplaySession> = {},
    timeoutMs = 500,
  ): Promise<FFplaySession> {
    return this.executeAsync(command, options, timeoutMs);
  }

  static async executeAsync(
    command: string,
    options: ExecuteOptions<FFplaySession> = {},
    timeoutMs = 500,
  ): Promise<FFplaySession> {
    const session = this.createSession(command, timeoutMs);
    this.activeSession = session;
    return session.executeAsync({
      ...options,
      completeCallback: completed => {
        if (this.activeSession?.sessionId === completed.sessionId) {
          this.activeSession = undefined;
        }
        options.completeCallback?.(completed);
      },
    });
  }

  static cancel(session: FFplaySession): void {
    session.cancel();
  }

  static getCurrentSession(): FFplaySession | undefined {
    return this.activeSession;
  }

  static get currentSession(): FFplaySession | undefined {
    return this.activeSession;
  }

  static get playing(): boolean {
    return this.activeSession?.isPlaying() ?? false;
  }

  static get paused(): boolean {
    return this.activeSession?.isPaused() ?? false;
  }

  static hasVideoStream(path: string): boolean {
    return NativeFFmpegKitExtended.ffplayHasVideoStream(path);
  }

  static getFFplaySessions(): FFplaySession[] {
    const data = JSON.parse(
      NativeFFmpegKitExtended.getSessionsJson('ffplay') || '[]',
    ) as Array<{sessionId: number; command: string}>;
    return data.map(item => new FFplaySession(item.sessionId, item.command));
  }
}
