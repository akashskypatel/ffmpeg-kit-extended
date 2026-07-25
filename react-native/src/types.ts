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
  AlwaysPrintLogs = 0,
  PrintLogsWhenNoCallbackDefined = 1,
  PrintLogsWhenGlobalCallbackNotDefined = 2,
  PrintLogsWhenSessionCallbackNotDefined = 3,
  NeverPrintLogs = 4,
}

/** Signals that can be ignored by the native FFmpeg runtime. */
export enum Signal {
  SigInt = 0,
  SigQuit = 1,
  SigPipe = 2,
  SigTerm = 3,
  SigXcpu = 4,
}

/** One native log message emitted by a session. */
export interface Log {
  /** ID of the session that emitted this message. */
  sessionId: number;
  /** Numeric FFmpeg log level; compare with `LogLevel` when applicable. */
  level: number;
  /** Message text exactly as buffered by the native wrapper. */
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
  sessionId: number;
  type: SessionType;
  state: SessionState;
  returnCode: number;
  /** Unix epoch timestamp in milliseconds. */
  createTime: number;
  /** Unix epoch timestamp in milliseconds, or `0` before execution starts. */
  startTime: number;
  /** Unix epoch timestamp in milliseconds, or `0` before completion. */
  endTime: number;
  /** Wall-clock execution duration in milliseconds. */
  duration: number;
  command: string;
  output: string;
  logs: string;
  failStackTrace: string;
  logsCount: number;
  statisticsCount: number;
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
