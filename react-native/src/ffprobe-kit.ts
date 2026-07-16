import NativeFFmpegKitExtended from './NativeFFmpegKitExtended';
import {FFprobeSession, MediaInformationSession} from './session';
import type {ExecuteOptions} from './types';

const MEDIA_INFO_COMMAND =
  '-v error -hide_banner -print_format json -show_format -show_streams -show_chapters -i';

export class FFprobeKit {
  static createSession(command: string): FFprobeSession {
    requireCommand(command);
    return new FFprobeSession(
      NativeFFmpegKitExtended.createFFprobeSession(command),
      command,
    );
  }

  static execute(
    command: string,
    options: ExecuteOptions<FFprobeSession> = {},
  ): Promise<FFprobeSession> {
    return this.executeAsync(command, options);
  }

  static executeAsync(
    command: string,
    options: ExecuteOptions<FFprobeSession> = {},
  ): Promise<FFprobeSession> {
    const session = this.createSession(command);
    return session.executeAsync(options);
  }

  static cancel(session: FFprobeSession): void {
    session.cancel();
  }

  static createMediaInformationSession(
    path: string,
    timeoutMs = 500,
  ): MediaInformationSession {
    requireCommand(path);
    const command = `${MEDIA_INFO_COMMAND} ${quoteMediaPath(path)}`;
    return new MediaInformationSession(
      NativeFFmpegKitExtended.createMediaInformationSession(command),
      command,
      timeoutMs,
    );
  }

  static async getMediaInformation(
    path: string,
    timeoutMs = 500,
  ): Promise<MediaInformationSession> {
    const session = this.createMediaInformationSession(path, timeoutMs);
    return session.executeAsync();
  }

  static getLastFFprobeSession(): FFprobeSession | undefined {
    const json = NativeFFmpegKitExtended.getLastSessionJson('ffprobe');
    if (!json) return undefined;
    const data = JSON.parse(json) as {sessionId: number; command: string};
    return new FFprobeSession(data.sessionId, data.command);
  }

  static getFFprobeSessions(): FFprobeSession[] {
    const data = JSON.parse(
      NativeFFmpegKitExtended.getSessionsJson('ffprobe') || '[]',
    ) as Array<{sessionId: number; command: string}>;
    return data.map(item => new FFprobeSession(item.sessionId, item.command));
  }
}

function requireCommand(command: string): void {
  if (!command.trim()) throw new Error('command must not be blank');
}

function quoteMediaPath(path: string): string {
  return /\s/.test(path) ? `"${path.replace(/(["\\])/g, '\\$1')}"` : path;
}
