/**
 * FFmpegKit Flutter Extended Plugin - A wrapper library for FFmpeg
 * Copyright (C) 2026 Akash Patel
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

/// Defines how log messages should be redirected to the console.
enum LogRedirectionStrategy {
  /// Always print logs to the console.
  alwaysPrintLogs(0),

  /// Print logs only if no log callback is defined for the session.
  printLogsWhenNoCallbackDefined(1),

  /// Print logs only if no global log callback is defined.
  printLogsWhenGlobalCallbackNotDefined(2),

  /// Print logs only if no session-specific log callback is defined.
  printLogsWhenSessionCallbackNotDefined(3),

  /// Never print logs to the console.
  neverPrintLogs(4);

  /// The integer value associated with the strategy.
  final int value;
  const LogRedirectionStrategy(this.value);
}

/// FFmpeg log levels used for filtering or identifying log message severity.
enum LogLevel {
  /// Standard error output.
  stderr(-16),

  /// No output.
  quiet(-8),

  /// Panic level (rare).
  panic(0),

  /// Fatal error level.
  fatal(8),

  /// Error level.
  error(16),

  /// Warning level.
  warning(24),

  /// Informational level.
  info(32),

  /// Detailed output.
  verbose(40),

  /// Debugging information.
  debug(48),

  /// Extremely detailed trace information.
  trace(56);

  /// The integer value associated with the log level.
  final int value;
  const LogLevel(this.value);

  /// Creates a [LogLevel] from its raw integer [value].
  static LogLevel fromValue(int value) => LogLevel.values.firstWhere(
        (e) => e.value == value,
        orElse: () => LogLevel.debug, // Default fallback
      );
}

/// Represents a single log entry emitted by FFmpeg.
class Log {
  /// The ID of the session that produced this log.
  final int sessionId;

  /// The raw integer log level.
  final int level;

  /// The log message content.
  final String message;

  /// Creates a [Log] entry.
  Log(this.sessionId, this.level, this.message);

  /// Gets the [LogLevel] representation of this log entry.
  LogLevel get logLevel => LogLevel.fromValue(level);

  @override
  String toString() => 'Log($sessionId, $logLevel, $message)';

  String toJson() =>
      '{"sessionId":$sessionId,"level":$level,"message":"$message"}';
}
