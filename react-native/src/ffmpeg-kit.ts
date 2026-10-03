import { getBackend } from './platform/backend-registry';
import { argumentsToString } from './arguments';
import { FFmpegSession } from './session';
import { FFmpegKitExtended } from './ffmpeg-kit-extended';
import type { FFmpegExecuteOptions } from './types';

const NativeFFmpegKitExtended = getBackend();

/**
 * High-level FFmpeg command API for transcoding, filtering, muxing, capture,
 * analysis, and other media-processing operations.
 *
 * Call `FFmpegKitExtended.initialize()` once before using this class. Commands
 * omit the `ffmpeg` executable name and execute asynchronously so the JavaScript
 * thread remains responsive.
 *
 * @hideconstructor
 * @category Execution
 */
export class FFmpegKit {
  /**
   * Creates a session without starting it.
   *
   * Use the returned object to install callbacks, inspect its ID, or enqueue it
   * later with `session.executeAsync()`.
   *
   * @throws `Error` when `command` is blank.
   */
  static createSession(command: string): FFmpegSession {
    requireCommand(command);
    return new FFmpegSession(
      NativeFFmpegKitExtended.createFFmpegSession(command),
      command
    );
  }

  /**
   * Creates a session from pre-tokenized FFmpeg arguments.
   *
   * This avoids manual quoting for paths and values containing whitespace.
   */
  static createSessionFromArguments(
    arguments_: readonly string[]
  ): FFmpegSession {
    if (arguments_.length === 0) throw new Error('arguments must not be empty');
    return new FFmpegSession(
      NativeFFmpegKitExtended.createFFmpegSessionFromArguments(arguments_),
      argumentsToString(arguments_)
    );
  }

  /**
   * Executes an FFmpeg command asynchronously.
   *
   * This is an alias of `executeAsync()` retained for API familiarity. Resolve
   * the returned promise, then inspect `getReturnCode()`, `getOutput()`, or the
   * supplied callbacks.
   */
  static execute(
    command: string,
    options: FFmpegExecuteOptions<FFmpegSession> = {}
  ): Promise<FFmpegSession> {
    return this.executeAsync(command, options);
  }

  /**
   * Creates, queues, and executes an FFmpeg session.
   *
   * The shared `SessionQueueManager` limits native concurrency. Log and
   * statistics callbacks are delivered from buffered native data while the
   * session runs. The promise resolves after final callbacks are delivered.
   */
  static executeAsync(
    command: string,
    options: FFmpegExecuteOptions<FFmpegSession> = {}
  ): Promise<FFmpegSession> {
    const session = this.createSession(command);
    return session.executeAsync(options);
  }

  /** Requests cancellation of a created, queued, or running FFmpeg session. */
  static cancel(session: FFmpegSession): Promise<void> {
    return session.cancel();
  }

  /** Returns the newest FFmpeg session retained in native history. */
  static getLastFFmpegSession(): FFmpegSession | undefined {
    return FFmpegKitExtended.getLastFFmpegSession();
  }

  /** Returns FFmpeg sessions currently retained in native history. */
  static getFFmpegSessions(): FFmpegSession[] {
    return FFmpegKitExtended.getFFmpegSessions();
  }
}

function requireCommand(command: string): void {
  if (!command.trim()) throw new Error('command must not be blank');
}
