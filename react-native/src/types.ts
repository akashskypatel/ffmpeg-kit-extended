/** Exit codes with package-defined convenience names. */
export enum ReturnCode {
  /** Command completed successfully. */
  Success = 0,
  /** Command was cancelled through the session API. */
  Cancel = 255,
}

/** Returns `true` when an FFmpegKit return code represents success. */
export const isSuccessReturnCode = (code: number): boolean =>
  code === ReturnCode.Success;

/** Returns `true` when an FFmpegKit return code represents cancellation. */
export const isCancelReturnCode = (code: number): boolean =>
  code === ReturnCode.Cancel;

/** Lifecycle state reported by every session. */
export enum SessionState {
  /** The native session exists but execution has not started. */
  Created = 0,
  /** The command is currently executing. */
  Running = 1,
  /** Native execution reached a terminal state; inspect the return code. */
  Completed = 2,
  /** Session startup or execution failed before normal completion. */
  Failed = 3,
}

/** Identifies which command engine owns a session. */
export type SessionType =
  | 'ffmpeg'
  | 'ffprobe'
  | 'ffplay'
  | 'media-information';

/** FFmpeg-compatible native log levels, ordered from least to most verbose. */
export enum LogLevel {
  /** Redirect only messages written to stderr. */
  Stderr = -16,
  /** Disable native log output. */
  Quiet = -8,
  /** Unrecoverable conditions that may terminate processing immediately. */
  Panic = 0,
  /** Fatal errors that prevent the command from continuing. */
  Fatal = 8,
  /** Processing errors. */
  Error = 16,
  /** Warnings that may not stop execution. */
  Warning = 24,
  /** Normal informational output. */
  Info = 32,
  /** Additional operational detail. */
  Verbose = 40,
  /** Debug output useful while diagnosing commands or integrations. */
  Debug = 48,
  /** Maximum native trace verbosity. */
  Trace = 56,
}

/**
 * Native log-printing strategies retained for API compatibility.
 *
 * Per-session callbacks in React Native are delivered by polling buffered
 * native logs. Use `FFmpegKitConfig.enableRedirection()` and callback options
 * for normal application integration.
 */
export enum LogRedirectionStrategy {
  /** Always print native log messages regardless of callback registration. */
  AlwaysPrintLogs = 0,
  /** Print logs only when the session has no callback. */
  PrintLogsWhenNoCallbackDefined = 1,
  /** Print logs only when no process-wide callback is defined. */
  PrintLogsWhenGlobalCallbackNotDefined = 2,
  /** Print logs only when the individual session has no callback. */
  PrintLogsWhenSessionCallbackNotDefined = 3,
  /** Never print native log messages through the native redirection path. */
  NeverPrintLogs = 4,
}

/** Signals that can be ignored by the native FFmpeg runtime. */
export enum Signal {
  /** Interrupt signal (`SIGINT`). */
  SigInt = 0,
  /** Quit signal (`SIGQUIT`). */
  SigQuit = 1,
  /** Broken-pipe signal (`SIGPIPE`). */
  SigPipe = 2,
  /** Termination signal (`SIGTERM`). */
  SigTerm = 3,
  /** CPU-time-limit signal (`SIGXCPU`). */
  SigXcpu = 4,
}

/** One native log message emitted by a session. */
export interface Log {
  /** ID of the session that emitted this message. */
  sessionId: number;
  /** Numeric FFmpeg log level; compare with `LogLevel` when applicable. */
  level: number;
  /** Message text, terminated with a line feed when non-empty. */
  message: string;
}

/** Progress values emitted while an FFmpeg processing session is running. */
export interface Statistics {
  /** ID of the FFmpeg session that produced this update. */
  sessionId: number;
  /** Number of video frames processed so far. */
  videoFrameNumber: number;
  /** Current video processing rate in frames per second. */
  videoFps: number;
  /** Current encoder quality/quantizer value reported by FFmpeg. */
  videoQuality: number;
  /** Current output size in bytes. */
  size: number;
  /** Current media timestamp in milliseconds. */
  time: number;
  /** Wall-clock processing time elapsed in milliseconds. */
  timeElapsed: number;
  /** Current bitrate in bits per second. */
  bitrate: number;
  /** Processing speed multiplier, where `1` is real time. */
  speed: number;
  /** Number of duplicated frames reported by FFmpeg. */
  dupFrames: number;
  /** Number of dropped frames reported by FFmpeg. */
  dropFrames: number;
}

/** Serialized state returned by the native session history API. */
export interface SessionSnapshot {
  /** Process-unique native identity; it is not persistent across restarts. */
  sessionId: number;
  /** Session kind represented by this snapshot. */
  type: SessionType;
  /** Lifecycle state recorded when the snapshot was read. */
  state: SessionState;
  /** Native return code, including the package cancellation value when applicable. */
  returnCode: number;
  /** Unix epoch timestamp in milliseconds. */
  createTime: number;
  /** Unix epoch timestamp in milliseconds, or `0` before execution starts. */
  startTime: number;
  /** Unix epoch timestamp in milliseconds, or `0` before completion. */
  endTime: number;
  /** Wall-clock execution duration in milliseconds. */
  duration: number;
  /** Normalized/original command representation associated with the wrapper. */
  command: string;
  /** Combined native console output retained for this session. */
  output: string;
  /** Retained log content from the native history API. */
  logs: string;
  /** Native failure stack trace, or an empty string when none was recorded. */
  failStackTrace: string;
  /** Number of retained native log entries. */
  logsCount: number;
  /** Number of retained native statistics entries. */
  statisticsCount: number;
  /** Whether additional native debug-log capture is enabled. */
  debugLogEnabled: boolean;
}

/** Called once after a session reaches a terminal state. */
export type SessionCompleteCallback<T> = (session: T) => void;

/** Called for each newly buffered log entry while a session is monitored. */
export type LogCallback<T> = (log: Log, session: T) => void;

/** Called for each newly buffered FFmpeg statistics entry. */
export type StatisticsCallback<T> = (
  statistics: Statistics,
  session: T,
) => void;

/** Common options accepted by asynchronous session execution. */
export interface ExecuteOptions<T> {
  /** Invoked before the execution promise resolves. */
  completeCallback?: SessionCompleteCallback<T>;
  /** Receives log entries in session order. */
  logCallback?: LogCallback<T>;
  /**
   * Interval used by the TypeScript layer to poll native state and buffered
   * callbacks. Values below 10 ms are clamped to 10 ms. Defaults to 50 ms.
   */
  pollIntervalMs?: number;
}

/** Execution options for FFmpeg sessions, including progress statistics. */
export interface FFmpegExecuteOptions<T> extends ExecuteOptions<T> {
  /** Receives FFmpeg progress/statistics updates in session order. */
  statisticsCallback?: StatisticsCallback<T>;
}
