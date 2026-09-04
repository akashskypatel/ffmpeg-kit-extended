import NativeFFmpegKitExtended from './NativeFFmpegKitExtended';
import {argumentsToString} from './arguments';
import {FFplaySession} from './session';
import type {ExecuteOptions} from './types';

/**
 * High-level FFplay API for native audio and video playback.
 *
 * Mount `FFplayView` before starting video playback. Audio-only commands do not
 * require a view. Playback controls are session-based; retain the returned
 * `FFplaySession` when your UI needs pause, resume, seek, stop, position, or
 * volume operations.
 */
export class FFplayKit {
  private static activeSession?: FFplaySession;

  /**
   * Creates a playback session without starting it.
   *
   * @param command FFplay arguments without the `ffplay` executable name.
   * @param timeoutMs Native startup/operation timeout in milliseconds.
   */
  static createSession(command: string, timeoutMs = 500): FFplaySession {
    if (!command.trim()) throw new Error('command must not be blank');
    return new FFplaySession(
      NativeFFmpegKitExtended.createFFplaySession(command),
      command,
      timeoutMs,
    );
  }

  /** Creates a playback session from pre-tokenized FFplay arguments. */
  static createSessionFromArguments(
    arguments_: readonly string[],
    timeoutMs = 500,
  ): FFplaySession {
    if (arguments_.length === 0) throw new Error('arguments must not be empty');
    return new FFplaySession(
      NativeFFmpegKitExtended.createFFplaySessionFromArguments(arguments_),
      argumentsToString(arguments_),
      timeoutMs,
    );
  }

  /** Alias of `executeAsync()`; resolves when playback ends or is stopped. */
  static async execute(
    command: string,
    options: ExecuteOptions<FFplaySession> = {},
    timeoutMs = 500,
  ): Promise<FFplaySession> {
    return this.executeAsync(command, options, timeoutMs);
  }

  /**
   * Creates, marks active, queues, and starts an FFplay session.
   *
   * The promise normally remains pending for the playback lifetime. Keep the
   * session from `createSession()` when controls are needed before completion,
   * or read `currentSession` after calling this method.
   */
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

  /** Requests cancellation of a playback session. */
  static cancel(session: FFplaySession): void {
    session.cancel();
  }

  /** Returns the session most recently started through `executeAsync()`. */
  static getCurrentSession(): FFplaySession | undefined {
    return this.activeSession;
  }

  /** Property form of `getCurrentSession()`. */
  static get currentSession(): FFplaySession | undefined {
    return this.activeSession;
  }

  /** Whether the current session reports active playback. */
  static get playing(): boolean {
    return this.activeSession?.isPlaying() ?? false;
  }

  /** Whether the current session reports a paused state. */
  static get paused(): boolean {
    return this.activeSession?.isPaused() ?? false;
  }

  /**
   * Synchronously checks whether an input contains a video stream.
   *
   * Use this to decide whether a visible `FFplayView` is required before
   * starting playback.
   */
  static hasVideoStream(path: string): boolean {
    return NativeFFmpegKitExtended.ffplayHasVideoStream(path);
  }

  /** Returns FFplay sessions currently retained in native history. */
  static getFFplaySessions(): FFplaySession[] {
    const data = JSON.parse(
      NativeFFmpegKitExtended.getSessionsJson('ffplay') || '[]',
    ) as Array<{sessionId: number; command: string}>;
    return data.map(item => new FFplaySession(item.sessionId, item.command));
  }
}
