import NativeFFmpegKitExtended from './NativeFFmpegKitExtended';
import {argumentsToString} from './arguments';
import {FFmpegSession} from './session';
import type {FFmpegExecuteOptions} from './types';

export class FFmpegKit {
  static createSession(command: string): FFmpegSession {
    requireCommand(command);
    return new FFmpegSession(
      NativeFFmpegKitExtended.createFFmpegSession(command),
      command,
    );
  }

  static createSessionFromArguments(arguments_: readonly string[]): FFmpegSession {
    return this.createSession(argumentsToString(arguments_));
  }

  /**
   * React Native execution is asynchronous by design so FFmpeg never blocks
   * the JavaScript runtime. The promise resolves when the session completes.
   */
  static execute(
    command: string,
    options: FFmpegExecuteOptions<FFmpegSession> = {},
  ): Promise<FFmpegSession> {
    return this.executeAsync(command, options);
  }

  static executeAsync(
    command: string,
    options: FFmpegExecuteOptions<FFmpegSession> = {},
  ): Promise<FFmpegSession> {
    const session = this.createSession(command);
    return session.executeAsync(options);
  }

  static cancel(session: FFmpegSession): void {
    session.cancel();
  }

  static getLastFFmpegSession(): FFmpegSession | undefined {
    const json = NativeFFmpegKitExtended.getLastSessionJson('ffmpeg');
    if (!json) return undefined;
    const data = JSON.parse(json) as {sessionId: number; command: string};
    return new FFmpegSession(data.sessionId, data.command);
  }

  static getFFmpegSessions(): FFmpegSession[] {
    const data = JSON.parse(
      NativeFFmpegKitExtended.getSessionsJson('ffmpeg') || '[]',
    ) as Array<{sessionId: number; command: string}>;
    return data.map(item => new FFmpegSession(item.sessionId, item.command));
  }
}

function requireCommand(command: string): void {
  if (!command.trim()) throw new Error('command must not be blank');
}
