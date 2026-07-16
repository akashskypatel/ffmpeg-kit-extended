export enum ReturnCode {
  Success = 0,
  Cancel = 255,
}

export const isSuccessReturnCode = (code: number): boolean =>
  code === ReturnCode.Success;
export const isCancelReturnCode = (code: number): boolean =>
  code === ReturnCode.Cancel;

export enum SessionState {
  Created = 0,
  Running = 1,
  Completed = 2,
  Failed = 3,
}

export type SessionType =
  | 'ffmpeg'
  | 'ffprobe'
  | 'ffplay'
  | 'media-information';

export enum LogLevel {
  Stderr = -16,
  Quiet = -8,
  Panic = 0,
  Fatal = 8,
  Error = 16,
  Warning = 24,
  Info = 32,
  Verbose = 40,
  Debug = 48,
  Trace = 56,
}

export enum LogRedirectionStrategy {
  AlwaysPrintLogs = 0,
  PrintLogsWhenNoCallbackDefined = 1,
  PrintLogsWhenGlobalCallbackNotDefined = 2,
  PrintLogsWhenSessionCallbackNotDefined = 3,
  NeverPrintLogs = 4,
}

export enum Signal {
  SigInt = 0,
  SigQuit = 1,
  SigPipe = 2,
  SigTerm = 3,
  SigXcpu = 4,
}

export interface Log {
  sessionId: number;
  level: number;
  message: string;
}

export interface Statistics {
  sessionId: number;
  videoFrameNumber: number;
  videoFps: number;
  videoQuality: number;
  size: number;
  time: number;
  timeElapsed: number;
  bitrate: number;
  speed: number;
  dupFrames: number;
  dropFrames: number;
}

export interface SessionSnapshot {
  sessionId: number;
  type: SessionType;
  state: SessionState;
  returnCode: number;
  createTime: number;
  startTime: number;
  endTime: number;
  duration: number;
  command: string;
  output: string;
  logs: string;
  failStackTrace: string;
  logsCount: number;
  statisticsCount: number;
  debugLogEnabled: boolean;
}

export type SessionCompleteCallback<T> = (session: T) => void;
export type LogCallback<T> = (log: Log, session: T) => void;
export type StatisticsCallback<T> = (
  statistics: Statistics,
  session: T,
) => void;

export interface ExecuteOptions<T> {
  completeCallback?: SessionCompleteCallback<T>;
  logCallback?: LogCallback<T>;
  pollIntervalMs?: number;
}

export interface FFmpegExecuteOptions<T> extends ExecuteOptions<T> {
  statisticsCallback?: StatisticsCallback<T>;
}
