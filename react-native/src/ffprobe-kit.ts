import NativeFFmpegKitExtended from './NativeFFmpegKitExtended';
import {FFprobeSession, MediaInformationSession} from './session';
import type {ExecuteOptions} from './types';

const MEDIA_INFO_COMMAND =
  '-v error -hide_banner -print_format json -show_format -show_streams -show_chapters -i';

/**
 * High-level FFprobe API for inspecting media files, URLs, streams, and devices.
 *
 * Call `FFmpegKitExtended.initialize()` once before use. Commands omit the
 * `ffprobe` executable name. For common structured metadata, prefer
 * `getMediaInformation()` over manually parsing FFprobe JSON output.
 */
export class FFprobeKit {
  /** Creates an FFprobe session without starting it. */
  static createSession(command: string): FFprobeSession {
    requireCommand(command);
    return new FFprobeSession(
      NativeFFmpegKitExtended.createFFprobeSession(command),
      command,
    );
  }

  /** Alias of `executeAsync()`; resolves when FFprobe finishes. */
  static execute(
    command: string,
    options: ExecuteOptions<FFprobeSession> = {},
  ): Promise<FFprobeSession> {
    return this.executeAsync(command, options);
  }

  /**
   * Creates, queues, and executes an FFprobe command.
   *
   * Use the session output for custom probes. For standard format, stream, and
   * chapter metadata, use `getMediaInformation()`.
   */
  static executeAsync(
    command: string,
    options: ExecuteOptions<FFprobeSession> = {},
  ): Promise<FFprobeSession> {
    const session = this.createSession(command);
    return session.executeAsync(options);
  }

  /** Requests cancellation of an FFprobe session. */
  static cancel(session: FFprobeSession): void {
    session.cancel();
  }

  /**
   * Creates a structured media-information session without starting it.
   *
   * @param path Local path, content-accessible path, or protocol URL supported
   * by the selected FFmpegKit bundle.
   * @param timeoutMs Native probe timeout in milliseconds. Defaults to 500.
   */
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

  /**
   * Probes one input and resolves with a completed media-information session.
   * Call `session.getMediaInformation()` to obtain the typed result.
   */
  static async getMediaInformation(
    path: string,
    timeoutMs = 500,
  ): Promise<MediaInformationSession> {
    const session = this.createMediaInformationSession(path, timeoutMs);
    return session.executeAsync();
  }

  /** Returns the newest FFprobe session retained in native history. */
  static getLastFFprobeSession(): FFprobeSession | undefined {
    const json = NativeFFmpegKitExtended.getLastSessionJson('ffprobe');
    if (!json) return undefined;
    const data = JSON.parse(json) as {sessionId: number; command: string};
    return new FFprobeSession(data.sessionId, data.command);
  }

  /** Returns FFprobe sessions currently retained in native history. */
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
