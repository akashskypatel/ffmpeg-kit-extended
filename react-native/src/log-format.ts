import type { Log } from './types';

/** Adds the missing line terminator required for one complete log entry. */
export function ensureLogMessageLineFeed(log: Log): Log {
  const message = log.message;
  if (
    typeof message !== 'string' ||
    message.length === 0 ||
    message.endsWith('\n')
  ) {
    return log;
  }
  return { ...log, message: `${message}\n` };
}

/**
 * Repairs combined native output only when it is the raw concatenation of the
 * supplied log entries. Unexpected native formatting is preserved.
 */
export function formatLogOutputIfMissingLineFeeds(
  nativeOutput: string,
  logs: readonly Log[]
): string {
  const rawOutput = logs
    .map(log => (typeof log.message === 'string' ? log.message : ''))
    .join('');
  if (rawOutput !== nativeOutput) return nativeOutput;
  return logs.map(ensureLogMessageLineFeed).map(log => log.message).join('');
}
